import { RedisClient } from 'bun';

const TRANSIT_NETWORK_VERSION_KEY = 'transit:network:version';

/** Moves API station metadata to a fresh namespace after an enrichment changes. */
export async function bumpTransitNetworkCacheVersion() {
  const redisURL = process.env.REDIS_URL;
  if (!redisURL) return;

  const redis = new RedisClient(redisURL);
  try {
    await redis.incr(TRANSIT_NETWORK_VERSION_KEY);
  } catch (cause) {
    // A Redis outage must not turn a committed station snapshot into a failure.
    console.error('[worker] could not bump transit cache version', cause);
  } finally {
    redis.close();
  }
}
