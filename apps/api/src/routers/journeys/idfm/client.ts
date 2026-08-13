import type { JourneyInput } from '@via/contract';

import { env } from '../../../env';
import { fetchJsonOrNull } from '../../../http/fetch-json-or-null';
import { parseIdfmJourneys } from './parse';

const JOURNEY_TIMEOUT_MS = 2_500;

export async function fetchIdfmJourneys(
  input: JourneyInput,
  now: Date,
  signal?: AbortSignal
) {
  if (!env.API_KEY_PRISM_IDFM) return null;
  const url = new URL(env.PRIM_JOURNEY_PLANNER_URL);
  url.searchParams.set('from', `${input.origin.longitude};${input.origin.latitude}`);
  url.searchParams.set(
    'to',
    `${input.destination.coordinate.longitude};${input.destination.coordinate.latitude}`
  );
  url.searchParams.set('count', String(input.limit));
  url.searchParams.set('data_freshness', 'realtime');
  url.searchParams.set('datetime', toNavitiaDate(now));

  const body = await fetchJsonOrNull(url, {
    headers: { apikey: env.API_KEY_PRISM_IDFM },
    signal,
    timeoutMs: JOURNEY_TIMEOUT_MS,
    logLabel: '[journeys] IDFM',
  });
  if (body === null) return null;
  const journeys = parseIdfmJourneys(body, input, now);
  return { status: journeys.length > 0 ? ('ready' as const) : ('no-route' as const), journeys };
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
