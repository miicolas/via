import { cityDemandVotes, db } from '@via/db';
import { count } from 'drizzle-orm';

export type CityDemandRepository = {
  countVotes: () => Promise<Map<string, number>>;
  recordVote: (input: { citySlug: string; voterHash: string }) => Promise<'recorded' | 'duplicate'>;
};

export function createDatabaseCityDemandRepository(): CityDemandRepository {
  return {
    async countVotes() {
      const rows = await db
        .select({ citySlug: cityDemandVotes.citySlug, votes: count() })
        .from(cityDemandVotes)
        .groupBy(cityDemandVotes.citySlug);

      return new Map(rows.map((row) => [row.citySlug, Number(row.votes)]));
    },

    /**
     * The composite primary key is the guard, not a prior SELECT: two requests
     * from the same visitor racing each other both reach the insert, and only
     * one of them gets a row back.
     */
    async recordVote({ citySlug, voterHash }) {
      const inserted = await db
        .insert(cityDemandVotes)
        .values({ citySlug, voterHash })
        .onConflictDoNothing()
        .returning({ citySlug: cityDemandVotes.citySlug });

      return inserted[0] ? 'recorded' : 'duplicate';
    },
  };
}
