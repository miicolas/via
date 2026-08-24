import {
  type Coordinate,
  type JourneyDestination,
  type JourneyInput,
  type JourneyMode,
  type NaturalJourneyInterpretation,
  type SearchResult,
  journeyModeSchema,
} from '@via/contract';
import * as z from 'zod';

import type { JourneyPlanner } from '../journeys/service';
import type { HandleRegistry } from './handles';
import type { ResponsesToolDefinition } from './openai-transport';

/** Server-enforced call budget: the model gets two lookups and one calculation. */
export const MAX_SEARCHES = 2;
export const MAX_PLANS = 1;
/** OpenAI never sees more than five candidates, and only as opaque handles. */
const PLACE_HANDLE_LIMIT = 5;
const JOURNEY_LIMIT = 4;

/** The narrow slice of the place pipeline the toolset needs; the service adapts it. */
export type PlaceSearcher = (
  query: string,
  options: { limit: number; origin?: Coordinate; signal?: AbortSignal }
) => Promise<{ results: SearchResult[]; banAvailable: boolean }>;

export type ToolsetConfig = {
  registry: HandleRegistry;
  searchPlaces: PlaceSearcher;
  planner: JourneyPlanner;
  currentLocation?: Coordinate;
  /** Resolved Home/Work, when the account has them. Empty until wired to profiles. */
  favorites?: { home?: SearchResult; work?: SearchResult };
  identity: string;
  /** The client's temporal context, used when the model asks for "now". */
  defaultRequestedAt: Date;
  now: Date;
  signal?: AbortSignal;
};

export type ToolCounters = { searchPlaces: number; planJourneys: number };

export type Toolset = {
  definitions: ResponsesToolDefinition[];
  runTool: (name: string, rawArguments: string) => Promise<string>;
  counters: ToolCounters;
  /** True once the model overran a budget or referenced an unknown handle. */
  guardrailTriggered: () => boolean;
};

const HOME_TOKENS = new Set(['maison', 'home', 'chez moi', 'à la maison']);
const WORK_TOKENS = new Set(['travail', 'boulot', 'bureau', 'work', 'au travail']);

const searchArgsSchema = z.object({ query: z.string().trim().min(1).max(200) });

const planArgsSchema = z.object({
  origin: z.discriminatedUnion('kind', [
    z.object({ kind: z.literal('current_location') }),
    z.object({ kind: z.literal('handle'), handle: z.string().min(1) }),
  ]),
  destination: z.object({ handle: z.string().min(1) }),
  datetimeRepresents: z.enum(['departure', 'arrival']).default('departure'),
  requestedAt: z.string().optional(),
  requiredModes: z.array(journeyModeSchema).max(3).optional(),
  excludedModes: z.array(journeyModeSchema).max(3).optional(),
  preferredModes: z.array(journeyModeSchema).max(3).optional(),
});

const MODES_JSON_SCHEMA = {
  type: 'array',
  items: { type: 'string', enum: journeyModeSchema.options },
  maxItems: 3,
} as const;

export function createToolset(config: ToolsetConfig): Toolset {
  const counters: ToolCounters = { searchPlaces: 0, planJourneys: 0 };
  let guardrail = false;

  const definitions: ResponsesToolDefinition[] = [
    {
      type: 'function',
      name: 'search_places',
      description:
        'Résout un lieu via Via (station ou adresse) et renvoie jusqu’à cinq handles opaques. ' +
        'Accepte aussi "maison"/"travail". La position actuelle n’a pas besoin de recherche : ' +
        'utilise origin.kind="current_location" dans plan_journeys.',
      strict: false,
      parameters: {
        type: 'object',
        properties: {
          query: {
            type: 'string',
            description: 'Nom du lieu à résoudre, ou "maison"/"travail".',
          },
        },
        required: ['query'],
        additionalProperties: false,
      },
    },
    {
      type: 'function',
      name: 'plan_journeys',
      description:
        'Calcule les itinéraires Via depuis une origine (handle ou position actuelle) vers une ' +
        'destination désignée uniquement par un handle issu de search_places. Aucune coordonnée libre.',
      strict: false,
      parameters: {
        type: 'object',
        properties: {
          origin: {
            description: 'Origine : position actuelle ou handle de lieu.',
            anyOf: [
              {
                type: 'object',
                properties: { kind: { const: 'current_location' } },
                required: ['kind'],
                additionalProperties: false,
              },
              {
                type: 'object',
                properties: { kind: { const: 'handle' }, handle: { type: 'string' } },
                required: ['kind', 'handle'],
                additionalProperties: false,
              },
            ],
          },
          destination: {
            type: 'object',
            properties: { handle: { type: 'string' } },
            required: ['handle'],
            additionalProperties: false,
          },
          datetimeRepresents: { type: 'string', enum: ['departure', 'arrival'] },
          requestedAt: { type: 'string', description: 'ISO 8601 ou "now".' },
          requiredModes: MODES_JSON_SCHEMA,
          excludedModes: MODES_JSON_SCHEMA,
          preferredModes: MODES_JSON_SCHEMA,
        },
        required: ['origin', 'destination', 'datetimeRepresents'],
        additionalProperties: false,
      },
    },
  ];

  async function runSearch(rawArguments: string): Promise<string> {
    counters.searchPlaces += 1;
    if (counters.searchPlaces > MAX_SEARCHES) {
      guardrail = true;
      return toolError(`Budget de recherche dépassé (maximum ${MAX_SEARCHES}).`);
    }
    const parsed = safeParseJson(rawArguments, searchArgsSchema);
    if (!parsed.ok) return toolError(parsed.message);

    const favorite = resolveFavorite(parsed.value.query, config.favorites);
    if (favorite) {
      const handle = config.registry.registerPlace(favorite);
      return toolResult({ places: [describePlace(handle, favorite)] });
    }

    const { results, banAvailable } = await config.searchPlaces(parsed.value.query, {
      limit: PLACE_HANDLE_LIMIT,
      origin: config.currentLocation,
      signal: config.signal,
    });
    const places = results.slice(0, PLACE_HANDLE_LIMIT).map((result) => {
      const handle = config.registry.registerPlace(result);
      return describePlace(handle, result);
    });
    return toolResult({ places, banAvailable });
  }

  async function runPlan(rawArguments: string): Promise<string> {
    counters.planJourneys += 1;
    if (counters.planJourneys > MAX_PLANS) {
      guardrail = true;
      return toolError(`Budget de calcul dépassé (maximum ${MAX_PLANS}).`);
    }
    const parsed = safeParseJson(rawArguments, planArgsSchema);
    if (!parsed.ok) return toolError(parsed.message);
    const args = parsed.value;

    let originResult: SearchResult | undefined;
    let originCoordinate: Coordinate;
    let originLabel: string;
    if (args.origin.kind === 'current_location') {
      if (!config.currentLocation) {
        return toolError('Position actuelle indisponible : demande un lieu de départ.');
      }
      originCoordinate = config.currentLocation;
      originLabel = 'Ma position';
    } else {
      const resolved = config.registry.resolvePlace(args.origin.handle);
      if (!resolved) {
        guardrail = true;
        return toolError('Handle d’origine inconnu.');
      }
      originResult = resolved;
      originCoordinate = resolved.coordinate;
      originLabel = resolved.name;
    }

    const destinationResult = config.registry.resolvePlace(args.destination.handle);
    if (!destinationResult) {
      guardrail = true;
      return toolError('Handle de destination inconnu.');
    }
    const destination = toJourneyDestination(destinationResult);

    const requestedAt = resolveRequestedAt(args.requestedAt, config.defaultRequestedAt);
    const requiredModes = args.requiredModes ?? [];
    const excludedModes = args.excludedModes ?? [];
    const preferredModes = args.preferredModes ?? [];

    const input: JourneyInput = {
      origin: originCoordinate,
      destination,
      limit: JOURNEY_LIMIT,
      requestedAt: requestedAt.toISOString(),
      datetimeRepresents: args.datetimeRepresents,
      requiredModes,
      excludedModes,
      preferredModes,
      originStationId: originResult?.kind === 'station' ? originResult.id : undefined,
    };

    const journeys = await config.planner.plan(input, {
      identity: config.identity,
      signal: config.signal,
    });

    const interpretation: NaturalJourneyInterpretation = {
      originLabel,
      origin: originResult,
      destination,
      destinationResult,
      requestedAt: requestedAt.toISOString(),
      datetimeRepresents: args.datetimeRepresents,
      requiredModes,
      excludedModes,
      preferredModes,
    };

    const planHandle = config.registry.registerPlan({ interpretation, journeys });
    return toolResult({
      planHandle,
      status: journeys.status,
      journeyCount: journeys.journeys.length,
    });
  }

  return {
    definitions,
    counters,
    guardrailTriggered: () => guardrail,
    runTool: async (name, rawArguments) => {
      if (name === 'search_places') return runSearch(rawArguments);
      if (name === 'plan_journeys') return runPlan(rawArguments);
      guardrail = true;
      return toolError(`Outil inconnu : ${name}.`);
    },
  };
}

function describePlace(handle: string, result: SearchResult) {
  return {
    handle,
    kind: result.kind,
    label: result.name,
    context: placeContext(result),
  };
}

/**
 * A dock carries no `context` on the wire — the client words it. The model
 * still needs something to read back, so the wording lives here.
 */
const VELIB_CONTEXT = 'Station Vélib’';

/** The line under the name, in the wording the model reads back to the user. */
function placeContext(result: SearchResult): string | undefined {
  switch (result.kind) {
    case 'station':
      return undefined;
    case 'address':
      return result.context;
    case 'bikeStation':
      return VELIB_CONTEXT;
  }
}

function toJourneyDestination(result: SearchResult): JourneyDestination {
  if (result.kind === 'station') {
    return { kind: 'station', id: result.id, name: result.name, coordinate: result.coordinate };
  }
  // A dock is somewhere you walk to, so it travels as an address; its own
  // result kind exists for rendering, not for routing.
  return {
    kind: 'address',
    id: result.id,
    name: result.name,
    context: placeContext(result) ?? '',
    coordinate: result.coordinate,
  };
}

function resolveFavorite(
  query: string,
  favorites: ToolsetConfig['favorites']
): SearchResult | undefined {
  const token = query.trim().toLowerCase();
  if (favorites?.home && HOME_TOKENS.has(token)) return favorites.home;
  if (favorites?.work && WORK_TOKENS.has(token)) return favorites.work;
  return undefined;
}

function resolveRequestedAt(raw: string | undefined, fallback: Date): Date {
  if (!raw || raw === 'now') return fallback;
  const instant = new Date(raw);
  return Number.isNaN(instant.getTime()) ? fallback : instant;
}

type ParseResult<T> = { ok: true; value: T } | { ok: false; message: string };

function safeParseJson<T>(raw: string, schema: z.ZodType<T>): ParseResult<T> {
  let json: unknown;
  try {
    json = JSON.parse(raw);
  } catch {
    return { ok: false, message: 'Arguments JSON invalides.' };
  }
  const result = schema.safeParse(json);
  if (!result.success) {
    return { ok: false, message: `Arguments refusés : ${z.prettifyError(result.error)}` };
  }
  return { ok: true, value: result.data };
}

function toolResult(payload: Record<string, unknown>): string {
  return JSON.stringify({ ok: true, ...payload });
}

function toolError(message: string): string {
  return JSON.stringify({ ok: false, error: message });
}

export type { JourneyMode };
