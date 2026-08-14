import type {
  Coordinate,
  Journey,
  JourneyDestination,
  JourneyInput,
  NaturalJourneyDraft,
  NaturalJourneyInput,
  NaturalJourneyResponse,
  RouteIntent,
  SearchResult,
} from '@via/contract';

import type { RedisClient } from '../../redis';
import { formatParisLongDate, formatParisTime, parisDate } from '../../time/paris';
import { preferredShare, type JourneyPlanner } from '../journeys/service';
import type { ServiceHorizon } from './horizon';
import type { NaturalLanguageModel, NaturalModelMetrics } from './model';
import type { PlaceResolution, PlaceResolver } from './place-resolver';
import { consumeNaturalJourneyBudget, isInNaturalJourneyRollout } from './rate-limit';

const UNSUPPORTED_MESSAGE = 'Via peut t’aider à préparer un trajet en Île-de-France';
const EXAMPLES = ['Depuis Châtelet, je veux être à Gare du Nord à 10 h', '12 rue de Rivoli avant 9 h'];

type NaturalJourneyServiceConfig = {
  enabled: boolean;
  rolloutPercent: number;
  personalLimit: number;
  personalWindowSeconds: number;
  breakerFailures: number;
  breakerCooldownSeconds: number;
};

type Dependencies = {
  redis: RedisClient;
  model: NaturalLanguageModel | null;
  places: PlaceResolver;
  journeys: JourneyPlanner;
  horizon: ServiceHorizon;
  clock: { now: () => Date };
  config: NaturalJourneyServiceConfig;
};

type Context = { identity: string; signal?: AbortSignal };

export type NaturalJourneyService = {
  submit: (input: NaturalJourneyInput, context: Context) => Promise<NaturalJourneyResponse>;
};

export function createNaturalJourneyService(dependencies: Dependencies): NaturalJourneyService {
  let consecutiveAiFailures = 0;
  let aiOpenUntil = 0;
  const aiGate = {
    isOpen: (now: Date) => now.getTime() < aiOpenUntil,
    success: () => { consecutiveAiFailures = 0; },
    failure: (now: Date) => {
      consecutiveAiFailures += 1;
      if (consecutiveAiFailures >= dependencies.config.breakerFailures) {
        aiOpenUntil = now.getTime() + dependencies.config.breakerCooldownSeconds * 1_000;
      }
    },
  };
  return {
    submit: async (input, context) => {
      const startedAt = performance.now();
      const now = dependencies.clock.now();
      const modelMetrics: NaturalModelMetrics[] = [];
      const response = await processInput(input, context, now, dependencies, modelMetrics, aiGate);
      const intent = responseIntent(response);
      console.info('[natural-journeys] résultat', {
        status: response.status,
        clarification:
          response.status === 'needs_clarification' ? response.fields.map((field) => field.target) : [],
        latencyMs: Math.round(performance.now() - startedAt),
        source: response.status === 'ready' ? response.journeys.source : undefined,
        answerSource: response.status === 'ready' ? response.answerSource : undefined,
        intent,
        model: modelMetrics[0]?.model,
        promptVersion: modelMetrics[0]?.promptVersion,
        inputTokens: modelMetrics.reduce((total, item) => total + item.inputTokens, 0),
        outputTokens: modelMetrics.reduce((total, item) => total + item.outputTokens, 0),
        costUsd: modelMetrics.reduce((total, item) => total + item.costUsd, 0),
        errorCode: response.status === 'unavailable' ? response.reason : undefined,
      });
      return response;
    },
  };
}

async function processInput(
  input: NaturalJourneyInput,
  context: Context,
  now: Date,
  dependencies: Dependencies,
  modelMetrics: NaturalModelMetrics[],
  aiGate: { isOpen: (now: Date) => boolean; success: () => void; failure: (now: Date) => void }
): Promise<NaturalJourneyResponse> {
  if (
    !dependencies.config.enabled ||
    !isInNaturalJourneyRollout(context.identity, dependencies.config.rolloutPercent)
  ) {
    return unavailable('ai');
  }

  let draft: NaturalJourneyDraft;
  if (input.action === 'submit') {
    if (!dependencies.model || aiGate.isOpen(now)) return unavailable('ai');
    let budget;
    try {
      budget = await consumeNaturalJourneyBudget(
        dependencies.redis,
        context.identity,
        dependencies.config.personalLimit,
        dependencies.config.personalWindowSeconds,
        now
      );
    } catch (cause) {
      console.error('[natural-journeys] budget Redis indisponible', cause);
      return unavailable('ai');
    }
    if (!budget.allowed) {
      return { status: 'rate_limited', message: 'Réessaie dans quelques minutes.' };
    }
    try {
      const interpreted = await dependencies.model.interpret(input.query, now, context.signal);
      modelMetrics.push(interpreted.metrics);
      draft = { intent: interpreted.intent };
      aiGate.success();
    } catch (cause) {
      console.error('[natural-journeys] interprétation indisponible', cause);
      aiGate.failure(now);
      return unavailable('ai');
    }
  } else {
    const submittedOrigin = input.origin ?? input.draft.origin;
    const submittedDestination = input.destination ?? input.draft.destination;
    const [origin, destination] = await Promise.all([
      submittedOrigin
        ? verifySubmittedResult(submittedOrigin, input.currentLocation, dependencies.places, context.signal)
        : undefined,
      submittedDestination
        ? verifySubmittedResult(
            submittedDestination,
            input.currentLocation,
            dependencies.places,
            context.signal
          )
        : undefined,
    ]);
    draft = {
      ...input.draft,
      origin,
      destination,
      intent: input.datetimeRepresents
        ? { ...input.draft.intent, datetimeRepresents: input.datetimeRepresents }
        : input.draft.intent,
    };
  }

  if (draft.intent.scope === 'unsupported') {
    return { status: 'unsupported', message: UNSUPPORTED_MESSAGE, examples: EXAMPLES };
  }

  const currentLocation = input.currentLocation;
  const resolved = await resolveDraft(draft, currentLocation, dependencies.places, context.signal);
  if ('response' in resolved) return resolved.response;
  draft = resolved.draft;

  const requestedAt = draft.intent.requestedAt;
  if (!requestedAt) return clarification(draft, [{ target: 'time', question: 'Pour quand ?', candidates: [] }]);
  let latestDate: string | null;
  try {
    latestDate = await dependencies.horizon.latestDate();
  } catch {
    latestDate = null;
  }
  if (latestDate && parisDate(new Date(requestedAt)) > latestDate) {
    return {
      status: 'unavailable',
      reason: 'date_out_of_range',
      message: `Les horaires sont disponibles jusqu’au ${formatParisLongDate(`${latestDate}T12:00:00+02:00`)}.`,
    };
  }

  const origin =
    draft.intent.origin.kind === 'current_location' ? currentLocation : draft.origin?.coordinate;
  if (!origin || !draft.destination || draft.intent.datetimeRepresents === 'ambiguous') {
    return unavailable('location');
  }
  const destination = toDestination(draft.destination);
  const journeyInput: JourneyInput = {
    origin,
    destination,
    limit: 4,
    requestedAt,
    datetimeRepresents: draft.intent.datetimeRepresents,
    requiredModes: draft.intent.requiredModes,
    excludedModes: draft.intent.excludedModes,
    preferredModes: draft.intent.preferredModes,
  };
  let journeys = await dependencies.journeys.plan(journeyInput, context);
  let lateNotice: string | undefined;
  if (journeys.status !== 'ready' && journeyInput.datetimeRepresents === 'arrival') {
    const late = await dependencies.journeys.plan(
      { ...journeyInput, requestedAt: now.toISOString(), datetimeRepresents: 'departure' },
      context
    );
    if (late.status === 'ready' && late.journeys[0]) {
      journeys = late;
      lateNotice = `Aucun trajet n’arrive à l’heure demandée. Le plus proche arrive à ${formatParisTime(late.journeys[0].arrivalAt)}.`;
    }
  }
  if (journeys.status !== 'ready' || !journeys.journeys[0]) return unavailable('journey');

  const preferenceNotice = lateNotice ?? preferredNotice(journeys.journeys[0], draft.intent);
  const interpretation = {
    originLabel:
      draft.intent.origin.kind === 'current_location' ? 'Ta position' : draft.origin?.name ?? 'Départ',
    destination,
    destinationResult: draft.destination,
    requestedAt,
    datetimeRepresents: draft.intent.datetimeRepresents,
    requiredModes: draft.intent.requiredModes,
    excludedModes: draft.intent.excludedModes,
    preferredModes: draft.intent.preferredModes,
  } as const;
  const deterministic = deterministicAnswer(interpretation.originLabel, destination.name, journeys.journeys[0]);
  const generatedAnswer = await dependencies.model?.writeAnswer(
    {
      originLabel: interpretation.originLabel,
      destinationLabel: destination.name,
      requestedAt,
      datetimeRepresents: interpretation.datetimeRepresents,
      journey: journeys.journeys[0],
      preferenceNotice,
    },
    context.signal
  );
  if (generatedAnswer?.metrics) modelMetrics.push(generatedAnswer.metrics);
  const aiAnswer = generatedAnswer?.answer;
  return {
    status: 'ready',
    answer: aiAnswer ?? deterministic,
    answerSource: aiAnswer ? 'ai' : 'deterministic',
    preferenceNotice,
    interpretation,
    journeys,
  };
}

async function verifySubmittedResult(
  submitted: SearchResult,
  currentLocation: Coordinate | undefined,
  resolver: PlaceResolver,
  signal?: AbortSignal
) {
  const resolution = await resolver.resolve(submitted.name, currentLocation, signal);
  if (resolution.status === 'resolved') {
    return sameResult(resolution.result, submitted) ? resolution.result : undefined;
  }
  if (resolution.status === 'ambiguous') {
    return resolution.candidates.find((candidate) => sameResult(candidate, submitted));
  }
  return undefined;
}

function sameResult(a: SearchResult, b: SearchResult) {
  return a.kind === b.kind && a.id === b.id;
}

function responseIntent(response: NaturalJourneyResponse) {
  const intent =
    response.status === 'ready'
      ? response.interpretation
      : response.status === 'needs_clarification'
        ? response.draft.intent
        : undefined;
  return intent
    ? {
        datetimeRepresents: intent.datetimeRepresents,
        requiredModes: intent.requiredModes,
        excludedModes: intent.excludedModes,
        preferredModes: intent.preferredModes,
      }
    : undefined;
}

async function resolveDraft(
  draft: NaturalJourneyDraft,
  currentLocation: Coordinate | undefined,
  resolver: PlaceResolver,
  signal?: AbortSignal
): Promise<{ draft: NaturalJourneyDraft } | { response: NaturalJourneyResponse }> {
  const fields: Extract<NaturalJourneyResponse, { status: 'needs_clarification' }>['fields'] = [];
  let origin = draft.origin;
  let destination = draft.destination;

  const [originResolution, destinationResolution] = await Promise.all([
    draft.intent.origin.kind === 'place' && !origin
      ? resolver.resolve(draft.intent.origin.query, currentLocation, signal)
      : null,
    draft.intent.destinationQuery && !destination
      ? resolver.resolve(draft.intent.destinationQuery, currentLocation, signal)
      : null,
  ]);

  if (draft.intent.origin.kind === 'current_location' && !currentLocation) {
    fields.push({ target: 'origin', question: 'D’où pars-tu ?', candidates: [] });
  } else if (originResolution) {
    if (originResolution.status === 'resolved') origin = originResolution.result;
    else fields.push(placeField('origin', 'De quel lieu pars-tu ?', originResolution));
  }

  if (!draft.intent.destinationQuery) {
    fields.push({ target: 'destination', question: 'Où veux-tu aller ?', candidates: [] });
  } else if (destinationResolution) {
    if (destinationResolution.status === 'resolved') destination = destinationResolution.result;
    else fields.push(placeField('destination', 'Quel lieu veux-tu choisir ?', destinationResolution));
  }

  if (draft.intent.datetimeRepresents === 'ambiguous') {
    fields.push({ target: 'time', question: 'Tu veux partir ou arriver à cette heure ?', candidates: [] });
  }

  const next = { ...draft, origin, destination };
  return fields.length > 0 ? { response: clarification(next, fields) } : { draft: next };
}

function placeField(
  target: 'origin' | 'destination',
  question: string,
  resolution: Exclude<PlaceResolution, { status: 'resolved' }>
) {
  return { target, question, candidates: resolution.candidates } as const;
}

function clarification(
  draft: NaturalJourneyDraft,
  fields: Extract<NaturalJourneyResponse, { status: 'needs_clarification' }>['fields']
): NaturalJourneyResponse {
  return { status: 'needs_clarification', draft, fields };
}

function toDestination(result: SearchResult): JourneyDestination {
  return result.kind === 'station'
    ? { kind: 'station', id: result.id, name: result.name, coordinate: result.coordinate }
    : {
        kind: 'address',
        id: result.id,
        name: result.name,
        context: result.context,
        coordinate: result.coordinate,
      };
}

function preferredNotice(journey: Journey, intent: RouteIntent) {
  if (intent.preferredModes.length === 0) return undefined;
  const modes = new Set(intent.preferredModes);
  const labels = intent.preferredModes.map(modeLabel).join(' ou ');
  return preferredShare(journey, modes) > 0.5
    ? `Cet itinéraire passe majoritairement en ${labels}.`
    : `Aucun itinéraire raisonnable majoritairement en ${labels} : voici le meilleur trajet.`;
}

function modeLabel(mode: RouteIntent['preferredModes'][number]) {
  return mode === 'rer' ? 'RER' : mode;
}

function deterministicAnswer(origin: string, destination: string, journey: { departureAt: string; arrivalAt: string }) {
  return `De ${origin} à ${destination} : départ ${formatParisTime(journey.departureAt)}, arrivée ${formatParisTime(journey.arrivalAt)} le ${formatParisLongDate(journey.arrivalAt)}.`;
}

function unavailable(reason: 'ai' | 'journey' | 'location'): NaturalJourneyResponse {
  const messages = {
    ai: 'La recherche en langage naturel est indisponible. La recherche classique reste accessible.',
    journey: 'Je n’ai pas trouvé d’itinéraire vérifiable.',
    location: 'J’ai besoin d’un point de départ pour calculer le trajet.',
  };
  return { status: 'unavailable', reason, message: messages[reason] };
}
