import type { JourneyInput, JourneyMode } from '@via/contract';

import { fetchJsonOrNull } from '../../../http/fetch-json-or-null';
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

type IdfmJourneyPlannerConfig = {
  apiKey: string;
  url: string;
  loadShapes: JourneyShapeLoader;
  timeoutMs?: number;
};

/** Production adapter for the Navitia journey planner exposed by IDFM. */
export function createIdfmJourneyPlanner({
  apiKey,
  url,
  loadShapes,
  timeoutMs = DEFAULT_TIMEOUT_MS,
}: IdfmJourneyPlannerConfig): IdfmJourneyPlanner {
  return {
    plan: async (input, requestedAt, signal) => {
      const requestUrl = journeyUrl(url, input, requestedAt);
      const body = await fetchJsonOrNull(requestUrl, {
        headers: { apikey: apiKey },
        signal,
        timeoutMs,
        logLabel: '[journeys] IDFM',
        telemetry: { provider: 'prim', product: 'journey_planner' },
      });
      if (body === null) return null;
      const parsed = parseIdfmJourneys(body, input, requestedAt);
      const journeys = await hydrateSparseJourneyGeometry(parsed, loadShapes);
      return { status: journeys.length > 0 ? 'ready' : 'no-route', journeys };
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
