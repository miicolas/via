import { env } from '../../../env';
import { fetchJsonOrNull } from '../../../http/fetch-json-or-null';

const PRIM_TIMEOUT_MS = 2_000;

/**
 * One authenticated round-trip to PRIM stop-monitoring. `null` means "PRIM did
 * not answer" — including when no API key is configured; the caller decides
 * what that costs.
 */
export async function fetchStopMonitoring(
  monitoringRef: string,
  signal?: AbortSignal
): Promise<unknown | null> {
  if (!env.API_KEY_PRISM_IDFM) return null;

  const url = new URL(env.PRIM_STOP_MONITORING_URL);
  url.searchParams.set('MonitoringRef', monitoringRef);

  return fetchJsonOrNull(url, {
    headers: { apikey: env.API_KEY_PRISM_IDFM },
    signal,
    timeoutMs: PRIM_TIMEOUT_MS,
    logLabel: '[departures] PRIM',
  });
}
