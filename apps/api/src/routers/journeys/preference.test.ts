import { expect, test } from 'bun:test';
import type { Journey, JourneyMode } from '@via/contract';

import { preferredShare, rankPreferredJourney } from './service';

test('promotes a reasonable journey that spends a majority of vehicle time on the preferred mode', () => {
  const fastest = makeJourney('fast', 1_800, [['metro', 1_500]]);
  const mostlyBus = makeJourney('bus', 2_100, [['bus', 1_100], ['metro', 700]]);
  const ranked = rankPreferredJourney([fastest, mostlyBus], ['bus']);

  expect(preferredShare(mostlyBus, new Set(['bus']))).toBeGreaterThan(0.5);
  expect(ranked[0]?.id).toBe('bus');
});

test('keeps the fastest journey when the preferred option exceeds either tolerance', () => {
  const fastest = makeJourney('fast', 1_800, [['metro', 1_500]]);
  const tooSlow = makeJourney('bus', 2_701, [['bus', 2_400]]);
  expect(rankPreferredJourney([fastest, tooSlow], ['bus'])[0]?.id).toBe('fast');
});

function makeJourney(
  id: string,
  durationSeconds: number,
  transit: Array<[JourneyMode, number]>
): Journey {
  return {
    id,
    qualifier: 'recommended',
    durationSeconds,
    walkingDurationSeconds: 120,
    transferCount: Math.max(0, transit.length - 1),
    departureAt: '2026-08-14T08:00:00Z',
    arrivalAt: new Date(Date.parse('2026-08-14T08:00:00Z') + durationSeconds * 1_000).toISOString(),
    status: 'normal',
    warnings: [],
    sections: transit.map(([mode, sectionDuration], index) => ({
      type: 'transit' as const,
      durationSeconds: sectionDuration,
      from: { name: `A${index}`, coordinate: { latitude: 48.8, longitude: 2.3 } },
      to: { name: `B${index}`, coordinate: { latitude: 48.9, longitude: 2.4 } },
      geometry: [],
      route: {
        id: `${mode}-${index}`,
        shortName: `${index + 1}`,
        longName: mode,
        mode,
        color: '#000000',
        textColor: '#ffffff',
      },
      stops: [],
    })),
  };
}
