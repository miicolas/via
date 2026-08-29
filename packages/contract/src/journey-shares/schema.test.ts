import { describe, expect, test } from 'bun:test';

import {
  journeyShareClientSnapshotSchema,
  journeyShareCreateInputSchema,
} from './schema';
import { JOURNEY_CLIENT_LIMITS } from '../journeys/schema';

const coordinate = { latitude: 48.8566, longitude: 2.3522 };
const journey = {
  id: 'journey-1',
  qualifier: 'recommended' as const,
  durationSeconds: 60,
  walkingDurationSeconds: 60,
  transferCount: 0,
  departureAt: '2026-08-29T10:00:00+02:00',
  arrivalAt: '2026-08-29T10:01:00+02:00',
  status: 'normal' as const,
  warnings: [],
  fare: { amountInCents: 250, currency: 'EUR' as const },
  sections: [{
    id: 'section-1',
    type: 'walk' as const,
    durationSeconds: 60,
    from: { name: 'Départ', coordinate },
    to: { name: 'Arrivée', coordinate },
    geometry: [coordinate],
    stops: [],
  }],
};

const snapshot = {
  schemaVersion: 1 as const,
  journey,
  generatedAt: '2026-08-29T10:01:00+02:00',
  locale: 'fr-FR',
  timeZone: 'Europe/Paris',
};

describe('bounded journey share creation', () => {
  test('keeps snapshot metadata, idempotency, and fare at the boundary', () => {
    const result = journeyShareCreateInputSchema.safeParse({
      snapshot,
      idempotencyKey: '0198b020-a215-7bb9-b584-5fede4f9ade5',
    });

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.snapshot.schemaVersion).toBe(1);
      expect(result.data.snapshot.locale).toBe('fr-FR');
      expect(result.data.snapshot.timeZone).toBe('Europe/Paris');
      expect(result.data.snapshot.journey.fare).toEqual({ amountInCents: 250, currency: 'EUR' });
    }
  });

  test('rejects an oversized geometry in a section', () => {
    const result = journeyShareClientSnapshotSchema.safeParse({
      ...snapshot,
      journey: {
        ...journey,
        sections: [{
          ...journey.sections[0],
          geometry: Array.from({ length: JOURNEY_CLIENT_LIMITS.geometryPointsPerSection + 1 }, () => coordinate),
        }],
      },
    });

    expect(result.success).toBe(false);
  });
});
