import type { Journey, JourneyInput, JourneyMode } from '@via/contract';

import {
  fetchJsonResult,
  type JsonFetchFailure,
} from '../../../http/fetch-json-or-null';
import { compactParisDateTime } from '../../../time/paris';
import type { IdfmJourneyPlanner } from '../service';
import { parseIdfmJourneys } from './parse';
import {
  hydrateSparseJourneyGeometry,
  type JourneyShapeLoader,
} from './shape-hydrator';

/**
 * Measured against the live PRIM planner rather than guessed: a one-leg journey
 * between two central stop areas answers in ~0.5 s and 114 kB, while a
 * three-leg one from a suburban address answers in ~1.2 s and 376 kB — because
 * `disable_geojson=false` makes every response carry the full shape of every
 * leg. Exactly the journeys a traveller far from the network needs are the
 * slowest and heaviest ones, so a ceiling twice the measured cost is spent
 * first on them.
 *
 * Overrunning it is not a slow answer, it is no answer: the call resolves to
 * null, the timetable fallback takes over, and a long journey it cannot build
 * reads on screen as "no line connects these two points". Five seconds keeps
 * four times the headroom on the heaviest measurement and still returns well
 * inside the fifteen the app waits.
 */
const DEFAULT_TIMEOUT_MS = 5_000;

/**
 * What one realtime source actually did, named at the seam. The distinction
 * matters downstream: an `empty` answer is a claim about the route that
 * deserves a second opinion, while a `refused` round-trip claims nothing.
 */
export type SourceAttempt =
  | { outcome: 'answered'; journeys: Journey[] }
  /** PRIM answered, and answered nothing — after this many draws from the load balancer. */
  | { outcome: 'empty'; attempts: 1 | 2 }
  /** The round-trip itself failed; nothing was learned about the route. */
  | { outcome: 'refused'; cause: JsonFetchFailure };

type IdfmJourneyPlannerConfig = {
  apiKey: string;
  url: string;
  loadShapes: JourneyShapeLoader;
  timeoutMs?: number;
  /**
   * Ask a second time, off the connection pool, when PRIM answers empty — see
   * the comment inside `plan` for why the fresh socket is the whole point.
   */
  retryEmptyAnswerOnFreshConnection?: boolean;
  /** Injectable transport for tests at the HTTP boundary. */
  fetcher?: (url: URL, init?: RequestInit) => Promise<Response>;
};

/** Production adapter for the Navitia journey planner exposed by IDFM. */
export function createIdfmJourneyPlanner({
  apiKey,
  url,
  loadShapes,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  retryEmptyAnswerOnFreshConnection = true,
  fetcher,
}: IdfmJourneyPlannerConfig): IdfmJourneyPlanner {
  return {
    plan: async (input, requestedAt, signal) => {
      const attempt = async (onAFreshConnection: boolean): Promise<SourceAttempt> => {
        const requestUrl = journeyUrl(url, input, requestedAt);
        const result = await fetchJsonResult(requestUrl, {
          headers: {
            apikey: apiKey,
            // Opting out of keep-alive costs a handshake and buys a new draw
            // from the load balancer — see the retry below for why that is the
            // whole point.
            ...(onAFreshConnection ? { Connection: 'close' } : {}),
          },
          signal,
          timeoutMs,
          logLabel: '[journeys] IDFM',
          telemetry: { provider: 'prim', product: 'journey_planner' },
          ...(fetcher ? { fetcher } : {}),
        });
        if (result.outcome !== 'success') {
          return { outcome: 'refused', cause: result.outcome };
        }
        const parsed = parseIdfmJourneys(result.body, input, requestedAt);
        const journeys = await hydrateSparseJourneyGeometry(parsed, loadShapes);
        return journeys.length > 0
          ? { outcome: 'answered', journeys }
          : { outcome: 'empty', attempts: 1 };
      };

      const first = await attempt(false);
      if (
        first.outcome !== 'empty' ||
        !retryEmptyAnswerOnFreshConnection ||
        signal?.aborted
      ) {
        return first;
      }
      /**
       * A genuine "no line connects these two points" is reproducible; PRIM
       * answering 200 with an empty body is not. Measured against the live
       * service: the same suburban request came back empty in long runs — ten
       * consecutive successes, then eight consecutive failures — while
       * twenty-six separate direct calls with the same key, URL, headers and
       * minute all carried four itineraries. Runs, not coin flips, and the one
       * thing separating the two callers is the socket: `fetch` keeps its
       * connection alive, so every request rides the pool back to whichever
       * backend answered the first one, and a desynchronized backend keeps the
       * caller for as long as the connection lives.
       *
       * So the retry is not just "ask again" — asking again down the same pipe
       * reaches the same broken backend. It asks on a new connection, which is
       * a new draw from the load balancer. One retry, only on an empty answer,
       * so a healthy answer costs nothing and a true dead end costs one
       * handshake before the timetable second opinion takes over.
       */
      console.info('[journeys] réponse IDFM vide, seconde demande sur une connexion neuve', {
        destinationKind: input.destination.kind,
      });
      const second = await attempt(true);
      // A refused retry changes nothing: the empty first answer is what stands.
      return second.outcome === 'answered' ? second : { outcome: 'empty', attempts: 2 };
    },
  };
}

export function journeyUrl(baseUrl: string, input: JourneyInput, requestedAt: Date) {
  const url = new URL(baseUrl);
  url.searchParams.set(
    'from',
    input.originStationId
      ? navitiaStopId(input.originStationId)
      : `${input.origin.longitude};${input.origin.latitude}`
  );
  url.searchParams.set(
    'to',
    input.destination.kind === 'station'
      ? navitiaStopId(input.destination.id)
      : `${input.destination.coordinate.longitude};${input.destination.coordinate.latitude}`
  );
  url.searchParams.set('count', String(input.limit));
  url.searchParams.set('data_freshness', 'realtime');
  // IDFM can omit section shapes when GeoJSON is disabled, which leaves the
  // map no choice but to draw a chord between two stops.
  url.searchParams.set('disable_geojson', 'false');
  url.searchParams.set('datetime', compactParisDateTime(requestedAt));
  url.searchParams.set('datetime_represents', input.datetimeRepresents ?? 'departure');
  if (input.requiresAccessibleStations) url.searchParams.set('wheelchair', 'true');
  // PRIM plans transit, and only transit. Asked for a direct path as well,
  // Navitia spends `count` slots on it and drops every transit journey that
  // arrives later than it — and a bike path beats a two-transfer metro journey
  // often enough that the list came back with nothing to ride. The walk and the
  // ride are computed on the device instead, where they cost no journey slot
  // and no street-network routing over a six-hour walk.
  url.searchParams.set('direct_path', 'none');
  for (const mode of input.requiredModes ?? []) {
    url.searchParams.append('allowed_id[]', physicalModeUri(mode));
  }
  for (const mode of input.excludedModes ?? []) {
    url.searchParams.append('forbidden_uris[]', physicalModeUri(mode));
  }
  return url;
}

function navitiaStopId(id: string) {
  return id.startsWith('stop_area:') || id.startsWith('stop_point:')
    ? id
    : `stop_area:${id}`;
}

function physicalModeUri(mode: JourneyMode) {
  switch (mode) {
    case 'metro': return 'physical_mode:Metro';
    case 'rer': return 'physical_mode:RapidTransit';
    case 'transilien': return 'physical_mode:LocalTrain';
    case 'tram': return 'physical_mode:Tramway';
    case 'bus': return 'physical_mode:Bus';
  }
}
