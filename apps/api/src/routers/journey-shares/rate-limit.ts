import { incrementFixedWindow } from "../../http/redis-rate-limit";
import type { RedisClient } from "../../redis";

const DAY_SECONDS = 24 * 60 * 60;
const DAILY_SHARES_PER_IDENTITY = 30;

/** A Redis outage must not prevent a deliberate share; the API still validates the payload. */
export async function withinJourneyShareQuota(
  redis: RedisClient,
  identityHash: string,
): Promise<boolean> {
  try {
    const count = await incrementFixedWindow(
      redis,
      `journey-share:day:${identityHash}`,
      DAY_SECONDS,
    );
    return count <= DAILY_SHARES_PER_IDENTITY;
  } catch {
    return true;
  }
}
