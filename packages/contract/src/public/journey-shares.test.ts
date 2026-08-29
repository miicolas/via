import { expect, test } from 'bun:test';

import {
  publicJourneyShareResponseSchema,
  type PublicJourneyShareResponse,
} from './journey-shares';

const validResponse = {
  snapshot: {
    schemaVersion: 1,
    generatedAt: '2026-08-29T10:00:00+02:00',
    locale: 'fr-FR',
    timeZone: 'Europe/Paris',
    journey: {
      durationSeconds: 1_800,
      walkingDurationSeconds: 240,
      transferCount: 1,
      departureAt: '2026-08-29T10:05:00+02:00',
      arrivalAt: '2026-08-29T10:35:00+02:00',
      status: 'normal',
      warnings: ['Correspondance courte'],
      sections: [
        {
          id: 'section-1',
          type: 'transit',
          durationSeconds: 1_560,
          from: {
            name: 'Châtelet',
            coordinate: { latitude: 48.8584, longitude: 2.347 },
          },
          to: {
            name: 'Nation',
            coordinate: { latitude: 48.848, longitude: 2.3958 },
          },
          departureAt: '2026-08-29T10:08:00+02:00',
          arrivalAt: '2026-08-29T10:34:00+02:00',
          geometry: [
            { latitude: 48.8584, longitude: 2.347 },
            { latitude: 48.848, longitude: 2.3958 },
          ],
          route: {
            shortName: 'A',
            longName: 'RER A',
            color: '#e2231a',
            textColor: '#ffffff',
          },
          direction: 'Marne-la-Vallée — Chessy',
        },
      ],
    },
  },
  expiresAt: '2026-09-28T10:00:00+02:00',
} satisfies PublicJourneyShareResponse;

test('accepts the minimal public journey shape', () => {
  expect(publicJourneyShareResponseSchema.parse(validResponse)).toEqual(validResponse);
});

test('requires the public fields and closes the enums', () => {
  const missingWarning = structuredClone(validResponse);
  delete (missingWarning.snapshot.journey as { warnings?: unknown }).warnings;
  expect(publicJourneyShareResponseSchema.safeParse(missingWarning).success).toBe(false);

  const unknownStatus = structuredClone(validResponse);
  (unknownStatus.snapshot.journey as { status: string }).status = 'cancelled';
  expect(publicJourneyShareResponseSchema.safeParse(unknownStatus).success).toBe(false);

  const unknownType = structuredClone(validResponse);
  (unknownType.snapshot.journey.sections[0] as { type: string }).type = 'scooter';
  expect(publicJourneyShareResponseSchema.safeParse(unknownType).success).toBe(false);
});

test('rejects private sentinel fields instead of stripping them', () => {
  const enriched = structuredClone(validResponse) as Record<string, unknown>;
  const snapshot = enriched.snapshot as Record<string, unknown>;
  const journey = snapshot.journey as Record<string, unknown>;
  journey.fare = { amountInCents: 999, currency: 'EUR' };
  journey.sections = [
    {
      ...(journey.sections as unknown[])[0] as Record<string, unknown>,
      stops: [{ id: 'private-stop' }],
      platform: 'quai privé',
      serviceId: 'private-service',
    },
  ];
  snapshot.createdAt = '2026-08-29T09:00:00+02:00';

  expect(publicJourneyShareResponseSchema.safeParse(enriched).success).toBe(false);
});
