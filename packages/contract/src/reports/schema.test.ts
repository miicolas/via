import { expect, test } from 'bun:test';

import { reportSubmissionInputSchema, stationStatusSchema } from './schema';

test('report submission requires a crowding level for crowding and accepts a station incident', () => {
  expect(reportSubmissionInputSchema.safeParse({
    id: '018f6f3e-22f1-7b3c-8f52-54b65c6a2c63',
    stationId: 'IDFM:station',
    category: 'crowding',
    value: 'occurrence',
  }).success).toBeFalse();

  expect(reportSubmissionInputSchema.parse({
    id: '018f6f3e-22f1-7b3c-8f52-54b65c6a2c63',
    stationId: 'IDFM:station',
    category: 'crowding',
    value: 'high',
    lineId: 'IDFM:C01371',
  })).toEqual({
    id: '018f6f3e-22f1-7b3c-8f52-54b65c6a2c63',
    stationId: 'IDFM:station',
    category: 'crowding',
    value: 'high',
    lineId: 'IDFM:C01371',
  });

  expect(reportSubmissionInputSchema.safeParse({
    id: '018f6f3e-22f1-7b3c-8f52-54b65c6a2c63',
    stationId: 'IDFM:station',
    category: 'pickpocket',
    value: 'resolved',
  }).success).toBeFalse();
});

test('station status exposes aggregate provenance without reporter identity', () => {
  const parsed = stationStatusSchema.parse({
    stationId: 'IDFM:station',
    generatedAt: '2026-08-23T10:00:00.000Z',
    accessibility: {
      state: 'unavailable',
      source: 'reported',
      label: 'Accès PMR signalé indisponible',
      reporterCount: 2,
      observedAt: '2026-08-23T09:55:00.000Z',
      expiresAt: '2026-08-23T11:25:00.000Z',
      confidence: 'confirmed',
    },
    incidents: [],
    wheelchairRouteExcluded: true,
  });

  expect(parsed.accessibility?.source).toBe('reported');
  expect(JSON.stringify(parsed)).not.toContain('user');
});
