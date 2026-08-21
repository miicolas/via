import type { NaturalJourneyInput, NaturalJourneyResult } from '@via/contract';

import type { RedisClient } from '../../redis';
import { tryConsumePersonalBudget } from '../journeys/rate-limit';
import type { JourneyPlanner } from '../journeys/service';
import { type AgentResult, runNaturalJourneyAgent } from './agent';
import { type CircuitBreaker, type CircuitBreakerConfig, createCircuitBreaker } from './circuit-breaker';
import { createHandleRegistry } from './handles';
import {
  type NaturalJourneyMetric,
  type NaturalJourneyOutcomeCategory,
  type TokenPricing,
  computeCostUsd,
  recordNaturalJourneyMetric,
} from './metrics';
import type { OpenAiResponsesTransport } from './openai-transport';
import { PROMPT_VERSION } from './prompt';
import { safetyIdentifier } from './safety-identifier';
import { type PlaceSearcher, createToolset } from './tools';

/** Shown for every recoverable double-failure; the client offers Retry + classic search. */
const DOUBLE_FAILURE_MESSAGE =
  'La recherche en langage naturel est momentanément indisponible. Réessaie ou utilise la recherche classique.';

const RATE_LIMIT_PREFIX = 'openai:natural:person';

export type NaturalJourneyServiceConfig = {
  model: string;
  timeoutMs: number;
  personalLimit: number;
  personalWindowSeconds: number;
  breaker: CircuitBreakerConfig;
  safetySecret: string;
  /** Null until gpt-5.6-luna pricing is pinned; keeps `costUsd` honest rather than 0. */
  pricing: TokenPricing | null;
};

export type NaturalJourneyServiceDeps = {
  redis: RedisClient;
  planner: JourneyPlanner;
  searchPlaces: PlaceSearcher;
  /** Null when OPENAI_API_KEY is absent: every submission is the double-failure. */
  transport: OpenAiResponsesTransport | null;
  clock: { now: () => Date };
  config: NaturalJourneyServiceConfig;
  /** Overridable so tests can drive breaker state directly. */
  breaker?: CircuitBreaker;
  /** Metric sink; defaults to the privacy-safe console recorder. */
  recordMetric?: (metric: NaturalJourneyMetric) => void;
};

export type NaturalJourneySubmitContext = { identity: string; signal?: AbortSignal };

export type NaturalJourneyService = {
  submit: (
    input: NaturalJourneyInput,
    context: NaturalJourneySubmitContext
  ) => Promise<NaturalJourneyResult>;
};

const NEVER_ABORT = new AbortController().signal;

export function createNaturalJourneyService(deps: NaturalJourneyServiceDeps): NaturalJourneyService {
  const { redis, planner, searchPlaces, transport, clock, config } = deps;
  const breaker = deps.breaker ?? createCircuitBreaker(redis, config.breaker);
  const recordMetric = deps.recordMetric ?? recordNaturalJourneyMetric;

  return {
    submit: async (input, context) => {
      const startedAt = clock.now().getTime();
      const emit = (category: NaturalJourneyOutcomeCategory, telemetry?: Telemetry) => {
        const tokens = telemetry?.usage ?? null;
        const metric: NaturalJourneyMetric = {
          source: 'openai',
          category,
          latencyMs: clock.now().getTime() - startedAt,
          toolCalls: telemetry?.toolCalls ?? { searchPlaces: 0, planJourneys: 0 },
          tokens,
          model: config.model,
          promptVersion: PROMPT_VERSION,
          costUsd: computeCostUsd(tokens, config.pricing),
        };
        recordMetric(metric);
      };

      // No key, or the breaker is open: answer the double-failure immediately.
      // Neither is an OpenAI call, so neither touches the breaker's counters.
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

      const registry = createHandleRegistry();
      const now = clock.now();
      const toolset = createToolset({
        registry,
        searchPlaces,
        planner,
        currentLocation: currentLocationOf(input),
        identity: context.identity,
        defaultRequestedAt: temporalContext(input, now),
        now,
        signal: context.signal,
      });

      let run;
      try {
        run = await runNaturalJourneyAgent({
          transport,
          toolset,
          registry,
          model: config.model,
          safetyIdentifier: safetyIdentifier(context.identity, config.safetySecret),
          userMessage: buildUserMessage(input, now),
          timeoutMs: config.timeoutMs,
          signal: context.signal ?? NEVER_ABORT,
        });
      } catch (error) {
        // A client disconnect is not an OpenAI failure: don't feed the breaker.
        emit('cancelled');
        throw error;
      }

      const telemetry: Telemetry = { usage: run.usage, toolCalls: run.toolCalls };
      const category = categoryOf(run.result);
      if (run.result.kind === 'error') {
        await breaker.recordFailure();
      } else {
        await breaker.recordSuccess();
      }
      emit(category, telemetry);
      return toResult(run.result);
    },
  };
}

type Telemetry = {
  usage: { input: number; output: number; total: number } | null;
  toolCalls: { searchPlaces: number; planJourneys: number };
};

function categoryOf(result: AgentResult): NaturalJourneyOutcomeCategory {
  if (result.kind === 'ready') return 'ready';
  if (result.kind === 'unsupported') return 'unsupported';
  return result.category;
}

function toResult(result: AgentResult): NaturalJourneyResult {
  if (result.kind === 'ready') {
    return { outcome: 'ready', interpretation: result.interpretation, journeys: result.journeys };
  }
  if (result.kind === 'unsupported') {
    return { outcome: 'unsupported', message: result.message, examples: result.examples };
  }
  return unavailable();
}

function unavailable(): NaturalJourneyResult {
  return { outcome: 'unavailable', message: DOUBLE_FAILURE_MESSAGE };
}

function currentLocationOf(input: NaturalJourneyInput) {
  return input.latitude !== undefined && input.longitude !== undefined
    ? { latitude: input.latitude, longitude: input.longitude }
    : undefined;
}

function temporalContext(input: NaturalJourneyInput, now: Date): Date {
  if (!input.requestedAt) return now;
  const instant = new Date(input.requestedAt);
  return Number.isNaN(instant.getTime()) ? now : instant;
}

function buildUserMessage(input: NaturalJourneyInput, now: Date): string {
  const lines = [`Phrase de l'utilisateur : ${input.query}`];
  lines.push(
    currentLocationOf(input)
      ? 'Position actuelle disponible : utilise origin.kind="current_location" si le départ est "ici".'
      : 'Position actuelle indisponible.'
  );
  lines.push(`Contexte temporel ("maintenant") : ${(input.requestedAt ?? now.toISOString())}.`);
  return lines.join('\n');
}
