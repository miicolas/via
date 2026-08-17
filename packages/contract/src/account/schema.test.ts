import { describe, expect, test } from 'bun:test';

import { accountSyncInputSchema } from './schema';

const common = {
  operationId: '0198b020-a215-7bb9-b584-5fede4f9ade5',
  occurredAt: '2026-08-16T12:00:00.000Z',
};

describe('account sync contract', () => {
  test('accepts every operation with its matching payload', () => {
    const result = accountSyncInputSchema.safeParse({
      operations: [
        {
          ...common,
          kind: 'favorite.upsert',
          station: {
            stationId: 'stop:1',
            name: 'Châtelet',
            savedAt: common.occurredAt,
            updatedAt: common.occurredAt,
          },
        },
        { ...common, operationId: crypto.randomUUID(), kind: 'favorite.remove', stationId: 'stop:1' },
        {
          ...common,
          operationId: crypto.randomUUID(),
          kind: 'recent.upsert',
          recent: {
            id: 'address:1',
            kind: 'address',
            name: 'Hôtel de Ville',
            coordinate: { latitude: 48.856, longitude: 2.352 },
            savedAt: common.occurredAt,
          },
        },
        {
          ...common,
          operationId: crypto.randomUUID(),
          kind: 'recent.remove',
          recentId: 'address:1',
        },
        { ...common, operationId: crypto.randomUUID(), kind: 'recent.clear' },
        {
          ...common,
          operationId: crypto.randomUUID(),
          kind: 'preferences.set',
          preferences: {
            preferredModes: ['metro', 'rer'],
            excludedModes: ['bus'],
            updatedAt: common.occurredAt,
          },
        },
      ],
    });

    expect(result.success).toBe(true);
  });

  test('rejects an operation whose payload is absent', () => {
    const result = accountSyncInputSchema.safeParse({
      operations: [{ ...common, kind: 'favorite.upsert' }],
    });

    expect(result.success).toBe(false);
  });
});
