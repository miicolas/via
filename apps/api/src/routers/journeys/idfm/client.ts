import type { JourneyInput, JourneyMode } from '@via/contract';

import { fetchJsonOrNull } from '../../../http/fetch-json-or-null';
import { compactParisDateTime } from '../../../time/paris';
import type { IdfmJourneyPlanner } from '../service';
import { parseIdfmJourneys } from './parse';

const DEFAULT_TIMEOUT_MS = 2_500;

type IdfmJourneyPlannerConfig = {
  apiKey: string;
  url: string;
  timeoutMs?: number;
};

/** Production adapter for the Navitia journey planner exposed by IDFM. */
export function createIdfmJourneyPlanner({
  apiKey,
  url,
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
      });
      if (body === null) return null;
      const journeys = parseIdfmJourneys(body, input, requestedAt);
      return { status: journeys.length > 0 ? 'ready' : 'no-route', journeys };
    },
  };
}

export function journeyUrl(baseUrl: string, input: JourneyInput, requestedAt: Date) {
  const url = new URL(baseUrl);
  url.searchParams.set('from', `${input.origin.longitude};${input.origin.latitude}`);
  url.searchParams.set(
    'to',
    `${input.destination.coordinate.longitude};${input.destination.coordinate.latitude}`
  );
  url.searchParams.set('count', String(input.limit));
  url.searchParams.set('data_freshness', 'realtime');
  url.searchParams.set('datetime', compactParisDateTime(requestedAt));
  url.searchParams.set('datetime_represents', input.datetimeRepresents ?? 'departure');
  for (const mode of input.requiredModes ?? []) {
    url.searchParams.append('allowed_id[]', physicalModeUri(mode));
  }
  for (const mode of input.excludedModes ?? []) {
    url.searchParams.append('forbidden_uris[]', physicalModeUri(mode));
  }
  return url;
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
