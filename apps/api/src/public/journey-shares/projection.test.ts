import { expect, test } from 'bun:test';

import type { JourneyShareResponse } from '@via/contract';
import { publicJourneyShareResponseSchema } from '@via/contract/public';

import { toPublicJourneyShare } from './projection';

const privateShare = {
  snapshot: {
    schemaVersion: 1,
    generatedAt: '2026-08-29T10:00:00+02:00',
    locale: 'fr-FR',
    timeZone: 'Europe/Paris',
    journey: {
      id: 'journey-private-id',
      qualifier: 'recommended',
      durationSeconds: 1_800,
      walkingDurationSeconds: 240,
      transferCount: 1,
      departureAt: '2026-08-29T10:05:00+02:00',
      arrivalAt: '2026-08-29T10:35:00+02:00',
      status: 'normal',
      warnings: ['Correspondance courte'],
      fare: { amountInCents: 215, currency: 'EUR' },
      accessibility: { condition: 'autonomous', label: 'PMR privée' },
      peak: {
        ratio: 0.9,
        level: 'peak',
        stationId: 'private-station',
        stationName: 'Station privée',
        label: 'Affluence privée',
      },
      reportedCrowding: {
        level: 'high',
        stationName: 'Station privée',
        label: 'Signalement privé',
        reporterCount: 3,
        expiresAt: '2026-08-29T11:00:00+02:00',
      },
      wheelchairReport: {
        stationName: 'Station privée',
        label: 'Accessibilité privée',
        reporterCount: 2,
        confidence: 'confirmed',
        expiresAt: '2026-08-29T11:00:00+02:00',
      },
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
          scheduledDepartureAt: '2026-08-29T10:07:00+02:00',
          scheduledArrivalAt: '2026-08-29T10:33:00+02:00',
          geometry: [
            { latitude: 48.8584, longitude: 2.347 },
            { latitude: 48.848, longitude: 2.3958 },
          ],
          route: {
            id: 'private-route-id',
            shortName: 'A',
            longName: 'RER A',
            mode: 'rer',
            color: '#e2231a',
            textColor: '#ffffff',
          },
          direction: 'Marne-la-Vallée — Chessy',
          platform: 'quai privé',
          stops: [
            {
              id: 'private-stop',
              stationId: 'private-station',
              name: 'Arrêt privé',
              coordinate: { latitude: 48.85, longitude: 2.37 },
              arrivalAt: '2026-08-29T10:20:00+02:00',
              departureAt: '2026-08-29T10:21:00+02:00',
            },
          ],
          serviceId: 'private-service',
          timingSource: 'realtime',
          departureStatus: 'on_time',
          boardingPosition: {
            car: 2,
            carCount: 8,
            zone: 'middle',
            reason: 'transfer',
            equipment: 'stairs',
          },
          exit: {
            id: 'private-exit',
            name: 'Sortie privée',
            number: 1,
            coordinate: { latitude: 48.848, longitude: 2.3958 },
            walkingMeters: 30,
          },
        },
      ],
    },
  },
  createdAt: '2026-08-29T09:00:00+02:00',
  expiresAt: '2026-09-28T10:00:00+02:00',
} satisfies JourneyShareResponse;

test('projects only the fields intentionally rendered by the public page', () => {
  const projected = toPublicJourneyShare(privateShare);

  expect(projected).toEqual({
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
            stops: [
              {
                name: 'Arrêt privé',
                arrivalAt: '2026-08-29T10:20:00+02:00',
                departureAt: '2026-08-29T10:21:00+02:00',
              },
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
  });
});

test('validates the reconstructed response with the strict public schema', () => {
  const projected = toPublicJourneyShare(privateShare);
  expect(publicJourneyShareResponseSchema.safeParse(projected).success).toBe(true);
  const serialized = JSON.stringify(projected);
  for (const sentinel of [
    'journey-private-id',
    'private-route-id',
    'private-station',
    'private-stop',
    'private-service',
    'quai privé',
    'Sortie privée',
    '215',
    'Affluence privée',
    'createdAt',
    'fare',
    'accessibility',
    'peak',
    'reportedCrowding',
    'wheelchairReport',
    'platform',
    'serviceId',
    'boardingPosition',
    'exit',
  ]) {
    expect(serialized).not.toContain(sentinel);
  }
});
