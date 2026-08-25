import type { Journey, JourneyInput, JourneysResponse, SearchResult } from '@via/contract';

import type { JourneyPlanner } from '../../journeys/service';
import type {
  OpenAiResponsesTransport,
  ResponsesRequest,
  ResponsesTurn,
} from '../openai-transport';
import type { NaturalJourneyServiceConfig } from '../service';
import type { PlaceSearcher } from '../tools';

export const NOW = new Date('2026-08-21T10:00:00.000Z');

const USAGE = { input: 100, output: 20, total: 120 };

export const STATION: SearchResult = {
  kind: 'station',
  id: 'stop_chatelet',
  name: 'Châtelet',
  coordinate: { latitude: 48.8583, longitude: 2.3477 },
  routes: [],
};

export const ADDRESS: SearchResult = {
  kind: 'address',
  id: '75104_8321_00012',
  name: '12 Rue de Rivoli',
  context: '75004 Paris',
  coordinate: { latitude: 48.8566, longitude: 2.3555 },
};

const ONE_JOURNEY = { id: 'journey_1' } as unknown as Journey;

export const JOURNEYS: JourneysResponse = {
  status: 'ready',
  source: 'gtfs-theoretical',
  generatedAt: NOW.toISOString(),
  journeys: [ONE_JOURNEY],
};

export const CONFIG: NaturalJourneyServiceConfig = {
  model: 'gpt-5.6-luna',
  reasoningEffort: 'minimal',
  timeoutMs: 8_000,
  personalLimit: 20,
  personalWindowSeconds: 900,
  breaker: { failureThreshold: 5, openSeconds: 60 },
  safetySecret: 'test-secret-key-at-least-16',
  pricing: null,
};

export function toolCallTurn(name: string, args: unknown, callId = 'call_1'): ResponsesTurn {
  return {
    id: 'resp',
    functionCalls: [{ callId, name, arguments: JSON.stringify(args) }],
    outputText: '',
    usage: USAGE,
  };
}

/** One assistant turn carrying several parallel function calls. */
export function toolCallsTurn(calls: Array<{ name: string; args: unknown }>): ResponsesTurn {
  return {
    id: 'resp',
    functionCalls: calls.map((call, index) => ({
      callId: `call_${index + 1}`,
      name: call.name,
      arguments: JSON.stringify(call.args),
    })),
    outputText: '',
    usage: USAGE,
  };
}

export function finalTurn(payload: unknown): ResponsesTurn {
  return { id: 'resp', functionCalls: [], outputText: JSON.stringify(payload), usage: USAGE };
}

export function rawFinalTurn(text: string): ResponsesTurn {
  return { id: 'resp', functionCalls: [], outputText: text, usage: USAGE };
}

type ScriptEntry = ResponsesTurn | { __throw: unknown };

export function throwingTurn(error: unknown): ScriptEntry {
  return { __throw: error };
}

/**
 * A deterministic Responses transport. It hands back scripted turns in order
 * and records every request so tests can assert `store: false`, the
 * `safety_identifier`, and the absence of any conversation state.
 */
export function scriptedTransport(turns: ScriptEntry[]) {
  const requests: ResponsesRequest[] = [];
  let index = 0;
  const transport: OpenAiResponsesTransport = {
    create: async (request) => {
      requests.push(request);
      const turn = turns[index];
      index += 1;
      if (turn === undefined) throw new Error('scriptedTransport: no scripted turn left');
      if ('__throw' in turn) throw turn.__throw;
      return turn;
    },
  };
  return { transport, requests, callCount: () => index };
}

export function fakePlanner(response: JourneysResponse = JOURNEYS) {
  const calls: Array<{ input: JourneyInput; identity: string }> = [];
  const planner: JourneyPlanner = {
    plan: async (input, context) => {
      calls.push({ input, identity: context.identity });
      return response;
    },
  };
  return { planner, calls };
}

export function fakeSearcher(results: SearchResult[] = [STATION, ADDRESS]) {
  const queries: string[] = [];
  const searchPlaces: PlaceSearcher = async (query) => {
    queries.push(query);
    return { results, banAvailable: true };
  };
  return { searchPlaces, queries };
}
