import { jobDb, timestamptz } from '@via/db';
import { sql } from 'drizzle-orm';

import { redis, type RedisClient } from '../../redis';

export const JOURNEY_SHARE_RETENTION_INTERVAL_MS = 60 * 60 * 1_000;
export const JOURNEY_SHARE_RETENTION_GRACE_MS = 7 * 24 * 60 * 60 * 1_000;
export const JOURNEY_SHARE_RETENTION_BATCH_SIZE = 500;
const ELECTION_TTL_SECONDS = 65 * 60;

export type JourneyShareRetentionRepository = {
  deleteExpired: (before: Date, limit: number) => Promise<number>;
};

export type JourneyShareRetentionDependencies = {
  readonly redisClient: Pick<RedisClient, 'set'>;
  readonly repository: JourneyShareRetentionRepository;
};

/** Rows remain queryable for this grace period so an expired link can answer 410. */
export function journeyShareRetentionCutoff(now: Date): Date {
  return new Date(now.getTime() - JOURNEY_SHARE_RETENTION_GRACE_MS);
}

const databaseRepository: JourneyShareRetentionRepository = {
  async deleteExpired(before, limit) {
    const rows = await jobDb.execute<{ tokenHash: string }>(sql`
      WITH candidates AS (
        SELECT candidate.token_hash
        FROM journey_shares AS candidate
        WHERE candidate.expires_at <= ${timestamptz(before)}
           OR (
             candidate.revoked_at IS NOT NULL
             AND candidate.revoked_at <= ${timestamptz(before)}
           )
        ORDER BY
          CASE
            WHEN candidate.revoked_at IS NOT NULL
             AND candidate.revoked_at <= ${timestamptz(before)}
            THEN candidate.revoked_at
            ELSE candidate.expires_at
          END,
          candidate.token_hash
        LIMIT ${limit}
      )
      DELETE FROM journey_shares AS share
      USING candidates
      WHERE share.token_hash = candidates.token_hash
      RETURNING share.token_hash AS "tokenHash"
    `);
    return rows.length;
  },
};

export async function purgeExpiredJourneyShares(
  before: Date,
  repository: JourneyShareRetentionRepository = databaseRepository,
): Promise<number> {
  return repository.deleteExpired(before, JOURNEY_SHARE_RETENTION_BATCH_SIZE);
}

/** Run one elected hourly cycle; exported so tests can avoid starting a timer. */
export async function runJourneyShareRetentionCycle({
  now = new Date(),
  redisClient = redis,
  repository = databaseRepository,
}: Partial<JourneyShareRetentionDependencies> & { readonly now?: Date } = {}): Promise<number> {
  const cycle = Math.floor(now.getTime() / JOURNEY_SHARE_RETENTION_INTERVAL_MS);
  const elected = await redisClient.set(
    `journey-shares:retention:${cycle}`,
    '1',
    { nx: true, ex: ELECTION_TTL_SECONDS },
  );
  if (!elected) return 0;
  return purgeExpiredJourneyShares(journeyShareRetentionCutoff(now), repository);
}

let timer: ReturnType<typeof setInterval> | undefined;

export function startJourneyShareRetentionRuntime(): void {
  if (process.env.NODE_ENV === 'test' || timer) return;
  const run = () => {
    void runJourneyShareRetentionCycle().catch(() => {
      // Keep the API alive; the next hourly election retries the failed pass.
      console.error('[journey-shares] retention purge failed');
    });
  };
  run();
  timer = setInterval(run, JOURNEY_SHARE_RETENTION_INTERVAL_MS);
}

export function stopJourneyShareRetentionRuntime(): void {
  if (timer) clearInterval(timer);
  timer = undefined;
}
