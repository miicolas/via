import { db } from '@via/db';
import { transitServiceDates } from '@via/db/schema';
import { max } from 'drizzle-orm';

export type ServiceHorizon = { latestDate: () => Promise<string | null> };

// The horizon only moves on a GTFS import, but the aggregate scans the whole
// calendar table — cache it instead of paying that scan on every request.
const HORIZON_TTL_MS = 10 * 60 * 1000;
let cached: { value: string; expiresAt: number } | undefined;

export const serviceHorizon: ServiceHorizon = {
  latestDate: async () => {
    if (cached && Date.now() < cached.expiresAt) return cached.value;
    const [row] = await db
      .select({ date: max(transitServiceDates.date) })
      .from(transitServiceDates);
    const value = row?.date ?? null;
    if (value !== null) cached = { value, expiresAt: Date.now() + HORIZON_TTL_MS };
    return value;
  },
};
