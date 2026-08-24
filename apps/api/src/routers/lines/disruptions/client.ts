import { env } from '../../../env';
import { fetchJsonOrNull } from '../../../http/fetch-json-or-null';

// The bulk endpoint returns every disruption on the network (several
// megabytes), so it gets far more room than the 2 s stop-monitoring cap.
const BULK_TIMEOUT_MS = 15_000;

/**
 * One authenticated round-trip to the PRIM disruptions bulk feed. `null` means
 * "PRIM did not answer" — including when no API key is configured; the caller
 * decides what that costs.
 */
export async function fetchDisruptionsBulk(signal?: AbortSignal): Promise<unknown | null> {
  if (!env.API_KEY_PRISM_IDFM) return null;

  return fetchJsonOrNull(new URL(env.PRIM_DISRUPTIONS_URL), {
    headers: { apikey: env.API_KEY_PRISM_IDFM },
    signal,
    timeoutMs: BULK_TIMEOUT_MS,
    logLabel: '[lines] PRIM disruptions',
    telemetry: { provider: 'prim', product: 'disruptions_bulk' },
  });
}
