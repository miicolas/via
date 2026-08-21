import { db } from '@via/db';
import { stationHourProfiles } from '@via/db/schema';
import { and, eq, inArray } from 'drizzle-orm';

import type { ParisDayType } from '../time/paris';

export type PeakLevel = 'off' | 'moderate' | 'peak';

export type StationPeak = {
  ratio: number;
  level: PeakLevel;
  label: string;
};

export const PEAK_LEVEL_LABELS: Record<PeakLevel, string> = {
  peak: 'heure la plus chargée',
  moderate: 'fréquentation soutenue',
  off: 'heure creuse',
};

export function peakLevelForRatio(ratio: number): PeakLevel {
  if (ratio >= 0.8) return 'peak';
  if (ratio >= 0.5) return 'moderate';
  return 'off';
}

/** Reads only the derived level for the requested stations and local hour. */
export async function stationPeaks(
  ids: Iterable<string>,
  dayType: ParisDayType,
  hour: number
): Promise<Map<string, StationPeak>> {
  const values = [...new Set([...ids].filter(Boolean))];
  if (values.length === 0 || !Number.isInteger(hour) || hour < 0 || hour > 23) {
    return new Map();
  }

  try {
    const rows = await db
      .select({ stopId: stationHourProfiles.stopId, ratio: stationHourProfiles.peakRatio })
      .from(stationHourProfiles)
      .where(
        and(
          inArray(stationHourProfiles.stopId, values),
          eq(stationHourProfiles.dayType, dayType),
          eq(stationHourProfiles.hour, hour)
        )
      );
    return new Map(
      rows.map((row) => {
        const ratio = Math.min(1, Math.max(0, row.ratio));
        const level = peakLevelForRatio(ratio);
        return [row.stopId, { ratio, level, label: PEAK_LEVEL_LABELS[level] } satisfies StationPeak];
      })
    );
  } catch (cause) {
    // A profile import or migration must never make journey/departure data
    // unavailable. Missing profiles are represented by an empty map.
    console.error('[station-peaks] profiles unavailable', cause);
    return new Map();
  }
}
