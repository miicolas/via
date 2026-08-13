import type { JourneyInput } from '@via/contract';

import { fetchJsonOrNull } from '../../../http/fetch-json-or-null';
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
    plan: async (input, now, signal) => {
      const requestUrl = journeyUrl(url, input, now);
      const body = await fetchJsonOrNull(requestUrl, {
        headers: { apikey: apiKey },
        signal,
        timeoutMs,
        logLabel: '[journeys] IDFM',
      });
      if (body === null) return null;
      const journeys = parseIdfmJourneys(body, input, now);
      return { status: journeys.length > 0 ? 'ready' : 'no-route', journeys };
    },
  };
}

function journeyUrl(baseUrl: string, input: JourneyInput, now: Date) {
  const url = new URL(baseUrl);
  url.searchParams.set('from', `${input.origin.longitude};${input.origin.latitude}`);
  url.searchParams.set(
    'to',
    `${input.destination.coordinate.longitude};${input.destination.coordinate.latitude}`
  );
  url.searchParams.set('count', String(input.limit));
  url.searchParams.set('data_freshness', 'realtime');
  url.searchParams.set('datetime', toNavitiaDate(now));
  return url;
}

function toNavitiaDate(now: Date) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/Paris',
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(now);
  const map = Object.fromEntries(parts.map(({ type, value }) => [type, value]));
  return `${map.year}${map.month}${map.day}T${map.hour === '24' ? '00' : map.hour}${map.minute}${map.second}`;
}
