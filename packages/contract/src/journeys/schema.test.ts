import { describe, expect, test } from 'bun:test';

import {
  JOURNEY_CLIENT_LIMITS,
  journeyDepartureChoicesInputSchema,
  journeyClientPayloadSchema,
} from './schema';

const coordinate = { latitude: 48.8566, longitude: 2.3522 };
const section = {
  id: 'section-1',
  type: 'walk' as const,
  durationSeconds: 60,
  from: { name: 'Départ', coordinate },
  to: { name: 'Arrivée', coordinate },
  geometry: [coordinate],
  stops: [],
};

const journey = {
  id: 'journey-1',
  qualifier: 'recommended' as const,
  durationSeconds: 60,
  walkingDurationSeconds: 60,
  transferCount: 0,
  departureAt: '2026-08-29T10:00:00+02:00',
  arrivalAt: '2026-08-29T10:01:00+02:00',
  status: 'normal' as const,
  warnings: ['Prévoir une minute'],
  fare: { amountInCents: 250, currency: 'EUR' as const },
  sections: [section],
};

const destination = {
  kind: 'station' as const,
  id: 'station-1',
  name: 'Arrivée',
  coordinate,
};

describe('bounded client journey payload', () => {
  test('accepts every collection at its documented limit and preserves fare', () => {
    const bounded = {
      ...journey,
      warnings: Array.from({ length: JOURNEY_CLIENT_LIMITS.warnings }, () => 'warning'),
      sections: Array.from({ length: JOURNEY_CLIENT_LIMITS.sections }, (_, index) => ({
        ...section,
        id: `section-${index}`,
        geometry: Array.from({ length: JOURNEY_CLIENT_LIMITS.geometryPointsPerSection }, () => coordinate),
        stops: Array.from({ length: JOURNEY_CLIENT_LIMITS.stopsPerSection }, (_, stopIndex) => ({
          id: `stop-${index}-${stopIndex}`,
          name: 'Arrêt',
          coordinate,
        })),
      })),
    };

    const parsed = journeyClientPayloadSchema.parse(bounded);

    expect(parsed.fare).toEqual({ amountInCents: 250, currency: 'EUR' });
    expect(parsed.sections).toHaveLength(JOURNEY_CLIENT_LIMITS.sections);
    expect(parsed.sections[0]?.geometry).toHaveLength(JOURNEY_CLIENT_LIMITS.geometryPointsPerSection);
    expect(parsed.sections[0]?.stops).toHaveLength(JOURNEY_CLIENT_LIMITS.stopsPerSection);
  });

  test.each([
    ['warnings', (value: unknown) => ({ ...journey, warnings: value })],
    ['sections', (value: unknown) => ({ ...journey, sections: value })],
    ['geometry', (value: unknown) => ({
      ...journey,
      sections: [{ ...section, geometry: value }],
    })],
    ['stops', (value: unknown) => ({
      ...journey,
      sections: [{ ...section, stops: value }],
    })],
  ])('rejects %s at one item above its limit', (_name, makePayload) => {
    const lengths = {
      warnings: JOURNEY_CLIENT_LIMITS.warnings + 1,
      sections: JOURNEY_CLIENT_LIMITS.sections + 1,
      geometry: JOURNEY_CLIENT_LIMITS.geometryPointsPerSection + 1,
      stops: JOURNEY_CLIENT_LIMITS.stopsPerSection + 1,
    };
    const key = _name as keyof typeof lengths;
    const value = Array.from({ length: lengths[key] }, () => key === 'stops'
      ? { id: 'stop', name: 'Arrêt', coordinate }
      : key === 'warnings' ? 'warning' : coordinate);

    expect(journeyClientPayloadSchema.safeParse(makePayload(value)).success).toBe(false);
  });

  test('departure choices use the bounded journey variant', () => {
    const result = journeyDepartureChoicesInputSchema.safeParse({
      journey: {
        ...journey,
        sections: [{
          ...section,
          geometry: Array.from({ length: JOURNEY_CLIENT_LIMITS.geometryPointsPerSection + 1 }, () => coordinate),
        }],
      },
      destination,
    });

    expect(result.success).toBe(false);
  });
});
