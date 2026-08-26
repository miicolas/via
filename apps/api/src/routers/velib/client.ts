import { env } from '../../env';
import { fetchJsonOrNull } from '../../http/fetch-json-or-null';

const VELIB_TIMEOUT_MS = 3_000;
/**
 * The two GBFS bodies are read by two consumers with two different parsers —
 * the Vélib' station snapshot and the shared-mobility aggregation. One
 * process-wide window keeps a single download behind both, so the same session
 * can never be handed two different dock counts for the same station.
 */
const FEED_FRESHNESS_MS = 55_000;

export type VelibFeeds = { information: unknown; status: unknown };

let cached: { feeds: VelibFeeds; expiresAt: number } | undefined;
let inFlight: Promise<VelibFeeds | null> | undefined;

export function fetchVelibFeeds(): Promise<VelibFeeds | null> {
  if (cached && cached.expiresAt > Date.now()) return Promise.resolve(cached.feeds);
  if (inFlight) return inFlight;

  inFlight = loadFeeds().finally(() => { inFlight = undefined; });
  return inFlight;
}

async function loadFeeds(): Promise<VelibFeeds | null> {
  const [information, status] = await Promise.all([
    fetchJsonOrNull(new URL(env.VELIB_STATION_INFORMATION_URL), {
      timeoutMs: VELIB_TIMEOUT_MS,
      logLabel: '[velib] station_information',
    }),
    fetchJsonOrNull(new URL(env.VELIB_STATION_STATUS_URL), {
      timeoutMs: VELIB_TIMEOUT_MS,
      logLabel: '[velib] station_status',
    }),
  ]);

  if (information === null || status === null) return null;
  const feeds = { information, status };
  cached = { feeds, expiresAt: Date.now() + FEED_FRESHNESS_MS };
  return feeds;
}
