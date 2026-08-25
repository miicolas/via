import type { NaturalJourneyInput, NaturalJourneyResult } from '@via/contract';

import type { RedisClient } from '../../redis';
import { tryConsumePersonalBudget } from '../journeys/rate-limit';
import { type CircuitBreaker, type CircuitBreakerConfig, createCircuitBreaker } from './circuit-breaker';
import {
  type NaturalJourneyMetric,
  type NaturalJourneyOutcomeCategory,
  type TokenPricing,
  computeCostUsd,
  recordNaturalJourneyMetric,
} from './metrics';
import type { OpenAiResponsesTransport, ReasoningEffort } from './openai-transport';
import {
  INTERPRETATION_OUTPUT_FORMAT,
  INTERPRETER_PROMPT_VERSION,
  INTERPRETER_SYSTEM_PROMPT,
  parseInterpretationOutput,
} from './prompt';
import { safetyIdentifier } from './safety-identifier';

const DOUBLE_FAILURE_MESSAGE =
  'La recherche en langage naturel est momentanément indisponible. Réessaie ou utilise la recherche classique.';
const RATE_LIMIT_PREFIX = 'openai:natural:person';
const MAX_OUTPUT_TOKENS = 1_200;

export type NaturalJourneyServiceConfig = {
  model: string;
  reasoningEffort: ReasoningEffort;
  timeoutMs: number;
  personalLimit: number;
  personalWindowSeconds: number;
  breaker: CircuitBreakerConfig;
  safetySecret: string;
  pricing: TokenPricing | null;
  /** Stable percentage gate. Zero is the immediate remote kill switch. */
  rolloutPercent: number;
};

export type NaturalJourneyServiceDeps = {
  redis: RedisClient;
  /** Null without OPENAI_API_KEY: the client receives a recoverable unavailable result. */
  transport: OpenAiResponsesTransport | null;
  clock: { now: () => Date };
  config: NaturalJourneyServiceConfig;
  breaker?: CircuitBreaker;
  recordMetric?: (metric: NaturalJourneyMetric) => void;
};

export type NaturalJourneySubmitContext = {
  identity: string;
  signal?: AbortSignal;
};

export type NaturalJourneyService = {
  submit: (
    input: NaturalJourneyInput,
    context: NaturalJourneySubmitContext,
  ) => Promise<NaturalJourneyResult>;
};

const NEVER_ABORT = new AbortController().signal;

/**
 * One stateless structured interpretation. This module deliberately has no
 * access to place search, saved-place coordinates or journey planning.
 */
export function createNaturalJourneyService(deps: NaturalJourneyServiceDeps): NaturalJourneyService {
  const { redis, transport, clock, config } = deps;
  const breaker = deps.breaker ?? createCircuitBreaker(redis, config.breaker);
  const recordMetric = deps.recordMetric ?? recordNaturalJourneyMetric;

  return {
    submit: async (input, context) => {
      const startedAt = clock.now().getTime();
      const emit = (
        category: NaturalJourneyOutcomeCategory,
        usage: { input: number; output: number; total: number } | null = null,
      ) => {
        recordMetric({
          source: 'openai',
          stage: 'interpretation',
          category,
          latencyMs: clock.now().getTime() - startedAt,
          tokens: usage,
          model: config.model,
          promptVersion: INTERPRETER_PROMPT_VERSION,
          costUsd: computeCostUsd(usage, config.pricing),
        });
      };

      if (!isInRollout(context.identity, config.rolloutPercent, config.safetySecret)) {
        emit('rollout-disabled');
        return unavailable();
      }

      if (!transport) {
        emit('no-key');
        return unavailable();
      }
      if (await breaker.isOpen()) {
        emit('circuit-open');
        return unavailable();
      }

      const personal = await tryConsumePersonalBudget(redis, {
        keyPrefix: RATE_LIMIT_PREFIX,
        identity: context.identity,
        limit: config.personalLimit,
        windowSeconds: config.personalWindowSeconds,
        now: clock.now(),
      });
      if (!personal.allowed) {
        emit('rate-limited');
        return unavailable();
      }

      const externalSignal = context.signal ?? NEVER_ABORT;
      if (externalSignal.aborted) {
        emit('cancelled');
        throw cancellation(externalSignal);
      }
      const timeoutSignal = AbortSignal.timeout(config.timeoutMs);
      const signal = AbortSignal.any([externalSignal, timeoutSignal]);

      let response;
      try {
        response = await transport.create(
          {
            model: config.model,
            input: [
              { role: 'system', content: INTERPRETER_SYSTEM_PROMPT },
              { role: 'user', content: buildUserMessage(input) },
            ],
            tools: [],
            text: { verbosity: 'low', format: INTERPRETATION_OUTPUT_FORMAT },
            reasoning: { effort: config.reasoningEffort },
            store: false,
            safety_identifier: safetyIdentifier(context.identity, config.safetySecret),
            max_output_tokens: MAX_OUTPUT_TOKENS,
          },
          signal,
        );
      } catch (error) {
        if (externalSignal.aborted) {
          emit('cancelled');
          throw cancellation(externalSignal);
        }
        await breaker.recordFailure();
        emit(timeoutSignal.aborted ? 'timeout' : 'openai-error');
        return unavailable();
      }

      if (response.functionCalls.length > 0) {
        await breaker.recordFailure();
        emit('invalid-output', response.usage);
        return unavailable();
      }

      const interpretation = parseInterpretationOutput(response.outputText);
      if (!interpretation || !isGroundedInterpretation(input, interpretation)) {
        await breaker.recordFailure();
        emit('invalid-output', response.usage);
        return unavailable();
      }

      await breaker.recordSuccess();
      emit('interpreted', response.usage);
      return { outcome: 'interpreted', interpretation };
    },
  };
}

function isGroundedInterpretation(
  input: NaturalJourneyInput,
  interpretation: Extract<NaturalJourneyResult, { outcome: 'interpreted' }>['interpretation'],
): boolean {
  const containsEvidence = (evidence: string) =>
    evidence.length === 0 || normalize(input.query).includes(normalize(evidence));
  const savedIds = new Set(input.savedPlaces.map((place) => place.id));
  const validPlace = (
    place: typeof interpretation.origin,
    allowsCurrentLocation: boolean,
  ) => {
    if (!place) return true;
    if (!containsEvidence(place.evidence)) return false;
    if (place.kind === 'current_location') {
      const currentLocationAliases = new Set([
        '', 'ma position', 'position actuelle', 'ici', 'd ici',
        'my location', 'current location', 'here',
      ]);
      return allowsCurrentLocation
        && place.value.length === 0
        && currentLocationAliases.has(normalize(place.evidence));
    }
    if (place.kind === 'context_reference') {
      return new Set([
        'previous_origin',
        'previous_destination',
        'uniquely_confirmed_place',
      ]).has(place.value) && place.evidence.length > 0;
    }
    if (place.kind === 'saved') return savedIds.has(place.value);
    const query = normalize(place.value);
    const evidence = normalize(place.evidence);
    return query.length > 0 && evidence.length > 0 && evidence.includes(query);
  };
  const matchesAnchor = (
    place: typeof interpretation.origin,
    anchor: NaturalJourneyInput['anchors']['origin'],
  ) => {
    if (place?.kind === 'context_reference' && !anchor) return false;
    return !anchor || (
      place?.kind === anchor.kind
      && place.value === anchor.value
      && place.evidence === anchor.evidence
    );
  };
  const validTime = (time: typeof interpretation.timeConstraint) => {
    const explicit = time.reference !== 'implicit_today'
      || time.timePrecision !== 'unspecified'
      || time.relativeAmount > 0;
    return containsEvidence(time.evidence) && (!explicit || time.evidence.length > 0);
  };
  const normalizedInput = normalize(input.query);
  const mentionedModes = new Set(
    ['metro', 'rer', 'transilien', 'tram', 'bus']
      .filter((mode) => normalizedInput.includes(mode)),
  );
  const modes = [
    ...interpretation.requiredModes,
    ...interpretation.excludedModes,
    ...interpretation.preferredModes,
  ];

  return validPlace(interpretation.origin, true)
    && validPlace(interpretation.destination, false)
    && (interpretation.origin?.kind === 'current_location'
      ? interpretation.originWasExplicit === (interpretation.origin.evidence.length > 0)
      : interpretation.origin
        ? interpretation.originWasExplicit
        : !interpretation.originWasExplicit)
    && matchesAnchor(interpretation.origin, input.anchors.origin)
    && matchesAnchor(interpretation.destination, input.anchors.destination)
    && validTime(interpretation.timeConstraint)
    && (!interpretation.alternateTimeConstraint
      || validTime(interpretation.alternateTimeConstraint))
    && modes.every((mode) => mentionedModes.has(mode))
    && (!interpretation.lastServiceOfDay
      || normalizedInput.includes('dernier')
      || normalizedInput.includes('last'))
    && containsEvidence(interpretation.unexplainedText)
    && interpretation.unsupportedConstraints.every(containsEvidence);
}

function normalize(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .toLocaleLowerCase('fr-FR');
}

function isInRollout(identity: string, percent: number, secret: string): boolean {
  if (percent <= 0) return false;
  if (percent >= 100) return true;
  const digest = safetyIdentifier(identity, secret);
  const bucket = Number.parseInt(digest.slice(0, 8), 16) % 100;
  return bucket < percent;
}

function buildUserMessage(input: NaturalJourneyInput): string {
  return JSON.stringify({
    locale: input.locale,
    now: input.requestedAt,
    hasCurrentLocation: input.hasCurrentLocation,
    lockedAnchors: input.anchors,
    savedPlaceAliases: input.savedPlaces,
    userInput: input.query,
  });
}

function unavailable(): NaturalJourneyResult {
  return { outcome: 'unavailable', message: DOUBLE_FAILURE_MESSAGE };
}

function cancellation(signal: AbortSignal): unknown {
  return signal.reason ?? new DOMException('The operation was aborted.', 'AbortError');
}
