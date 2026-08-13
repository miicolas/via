import type { JourneyInput, JourneysResponse } from '@via/contract';

import { fetchIdfmJourneys } from './idfm/client';
import { createGtfsLoader } from './gtfs/loader';
import { planWithGtfs } from './gtfs/planner';

/**
 * Deep journey seam: callers know one operation and one response; source
 * selection, quota decisions (performed by the handler), parsing and GTFS
 * reconstruction stay behind this module.
 */
export async function calculateJourneys(
  input: JourneyInput,
  now: Date,
  signal?: AbortSignal,
  options: { realtimeAllowed?: boolean } = {}
): Promise<JourneysResponse> {
  const realtime = options.realtimeAllowed === false ? null : await fetchIdfmJourneys(input, now, signal);
  if (realtime) {
    return {
      status: realtime.status,
      source: 'idfm-realtime',
      generatedAt: now.toISOString(),
      journeys: realtime.journeys,
    };
  }

  try {
    const theoretical = await planWithGtfs(
      input.origin,
      input.destination,
      now,
      input.limit,
      createGtfsLoader(now)
    );
    return { ...theoretical, generatedAt: now.toISOString() };
  } catch (cause) {
    console.error('[journeys] planificateur GTFS indisponible', cause);
    return {
      status: 'unavailable',
      source: 'gtfs-theoretical',
      generatedAt: now.toISOString(),
      journeys: [],
    };
  }
}
