import { describe, expect, test } from 'bun:test';
import { stationCrowdingSchema } from '@via/contract';

import type { StationHourProfileRow } from './queries';
import { toStationCrowding } from './to-station-crowding';

function fullRows(ratioFor: (dayType: string, hour: number) => number): StationHourProfileRow[] {
  const dayTypes = ['weekday', 'saturday', 'sunday'] as const;
  return dayTypes.flatMap((dayType) =>
    Array.from({ length: 24 }, (_, hour) => ({ dayType, hour, ratio: ratioFor(dayType, hour) }))
  );
}

describe('toStationCrowding', () => {
  test('a station without rows carries no profiles at all', () => {
    const crowding = toStationCrowding([]);

    expect(crowding).toEqual({});
    expect(stationCrowdingSchema.parse(crowding)).toEqual({});
  });

  test('a full profile yields 24 sorted hours per day type', () => {
    const crowding = toStationCrowding(fullRows((_, hour) => hour / 23));

    const profiles = crowding.profiles;
    expect(profiles).toBeDefined();
    for (const dayType of ['weekday', 'saturday', 'sunday'] as const) {
      expect(profiles?.[dayType].map((entry) => entry.hour)).toEqual(
        Array.from({ length: 24 }, (_, hour) => hour)
      );
    }
    expect(stationCrowdingSchema.parse(crowding)).toEqual(crowding);
  });

  test('levels follow the shared 0.5 and 0.8 thresholds', () => {
    const crowding = toStationCrowding(
      fullRows((_, hour) => (hour === 8 ? 1 : hour === 12 ? 0.6 : 0.1))
    );

    const weekday = crowding.profiles?.weekday;
    expect(weekday?.[8]).toEqual({ hour: 8, ratio: 1, level: 'peak' });
    expect(weekday?.[12]).toEqual({ hour: 12, ratio: 0.6, level: 'moderate' });
    expect(weekday?.[3]).toEqual({ hour: 3, ratio: 0.1, level: 'off' });
  });

  test('out-of-range ratios are clamped into 0..1', () => {
    const crowding = toStationCrowding(
      fullRows((_, hour) => (hour === 8 ? 1.2 : hour === 4 ? -0.1 : 0.2))
    );

    expect(crowding.profiles?.weekday[8]?.ratio).toBe(1);
    expect(crowding.profiles?.weekday[4]?.ratio).toBe(0);
    expect(stationCrowdingSchema.parse(crowding)).toEqual(crowding);
  });

  test('a half-completed import back-fills missing hours as quiet', () => {
    const partial = fullRows(() => 0.9).filter(
      (row) => !(row.dayType === 'saturday' && row.hour >= 12)
    );

    const crowding = toStationCrowding(partial);

    expect(crowding.profiles?.saturday).toHaveLength(24);
    expect(crowding.profiles?.saturday[15]).toEqual({ hour: 15, ratio: 0, level: 'off' });
    expect(stationCrowdingSchema.parse(crowding)).toEqual(crowding);
  });
});
