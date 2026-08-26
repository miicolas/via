import type { CrowdingHour, StationCrowding } from '@via/contract';

import { peakLevelForRatio } from '../station-peak';
import type { StationHourProfileRow } from './queries';

const DAY_TYPES = ['weekday', 'saturday', 'sunday'] as const;

/**
 * A station with no rows — every bus stop — yields no `profiles` at all rather
 * than three flat curves, so the client can drop the section instead of drawing
 * an empty chart. The importer writes all 24 hours per day type, but a
 * half-completed import must not break the contract's `.length(24)`, so missing
 * hours are back-filled as quiet.
 */
export function toStationCrowding(rows: StationHourProfileRow[]): StationCrowding {
  if (rows.length === 0) return {};

  const profiles = {} as Record<(typeof DAY_TYPES)[number], CrowdingHour[]>;
  for (const dayType of DAY_TYPES) {
    const byHour = new Map(rows.filter((row) => row.dayType === dayType).map((row) => [row.hour, row]));
    profiles[dayType] = Array.from({ length: 24 }, (_, hour) => {
      const ratio = Math.min(1, Math.max(0, byHour.get(hour)?.ratio ?? 0));
      return { hour, ratio, level: peakLevelForRatio(ratio) };
    });
  }
  return { profiles };
}
