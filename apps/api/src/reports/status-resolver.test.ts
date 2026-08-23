import { expect, test } from 'bun:test';

import {
  deriveReportScope,
  resolveStationStatus,
  type CurrentReportVote,
} from './status-resolver';

const stationId = 'IDFM:station';
const now = new Date('2026-08-23T10:00:00.000Z');
const minutesAgo = (minutes: number) => new Date(now.getTime() - minutes * 60_000);

function vote(overrides: Partial<CurrentReportVote> = {}): CurrentReportVote {
  return {
    reporterId: 'user-1',
    stationId,
    category: 'wheelchairAccessUnavailable',
    scopeKind: 'station',
    scopeId: stationId,
    value: 'occurrence',
    observedAt: new Date('2026-08-23T09:50:00.000Z'),
    ...overrides,
  };
}

test('a recent wheelchair report replaces the automatic accessibility display until it expires', () => {
  const active = resolveStationStatus({
    stationId,
    at: now,
    automaticAccessibility: {
      condition: 'autonomous',
      label: 'En autonomie',
    },
    votes: [vote()],
  });

  expect(active.accessibility).toEqual({
    state: 'unavailable',
    source: 'reported',
    label: 'Accès PMR signalé indisponible',
    reporterCount: 1,
    observedAt: '2026-08-23T09:50:00.000Z',
    expiresAt: '2026-08-23T10:50:00.000Z',
    confidence: 'observed',
  });

  const expired = resolveStationStatus({
    stationId,
    at: new Date('2026-08-23T10:51:00.000Z'),
    automaticAccessibility: {
      condition: 'autonomous',
      label: 'En autonomie',
    },
    votes: [vote()],
  });

  expect(expired.accessibility).toEqual({
    state: 'available',
    source: 'automatic',
    condition: 'autonomous',
    label: 'En autonomie',
  });
});

test('two recent wheelchair reports confirm the incident and extend it without counting duplicate authors', () => {
  const status = resolveStationStatus({
    stationId,
    at: now,
    votes: [
      vote({ reporterId: 'user-1', observedAt: new Date('2026-08-23T09:40:00.000Z') }),
      vote({ reporterId: 'user-2', observedAt: new Date('2026-08-23T09:50:00.000Z') }),
      vote({ reporterId: 'user-2', observedAt: new Date('2026-08-23T09:55:00.000Z') }),
    ],
  });

  expect(status.accessibility).toMatchObject({
    state: 'unavailable',
    reporterCount: 2,
    confidence: 'confirmed',
    observedAt: '2026-08-23T09:55:00.000Z',
    expiresAt: '2026-08-23T11:25:00.000Z',
  });
  expect(status.wheelchairRouteExcluded).toBeTrue();
});

test('two more recent recovery confirmations restore automatic accessibility', () => {
  const status = resolveStationStatus({
    stationId,
    at: now,
    automaticAccessibility: { condition: 'staffAssistance', label: 'Avec assistance' },
    votes: [
      vote({ reporterId: 'failure-1', observedAt: new Date('2026-08-23T09:20:00.000Z') }),
      vote({ reporterId: 'failure-2', observedAt: new Date('2026-08-23T09:25:00.000Z') }),
      vote({ reporterId: 'recovery-1', value: 'resolved', observedAt: new Date('2026-08-23T09:50:00.000Z') }),
      vote({ reporterId: 'recovery-2', value: 'resolved', observedAt: new Date('2026-08-23T09:55:00.000Z') }),
    ],
  });

  expect(status.accessibility).toEqual({
    state: 'available',
    source: 'automatic',
    condition: 'staffAssistance',
    label: 'Avec assistance',
  });
  expect(status.incidents).toContainEqual({
    category: 'wheelchairAccessUnavailable',
    scopeKind: 'station',
    scopeId: stationId,
    state: 'recovered',
    label: 'Rétabli selon 2 personnes',
    reporterCount: 2,
    observedAt: '2026-08-23T09:55:00.000Z',
    expiresAt: '2026-08-23T11:25:00.000Z',
  });
  expect(status.wheelchairRouteExcluded).toBeFalse();
});

test('recent crowding majority replaces the habitual profile and extends with distinct supporters', () => {
  const status = resolveStationStatus({
    stationId,
    at: now,
    automaticCrowding: { level: 'high', label: 'heure la plus chargée' },
    votes: [
      vote({
        reporterId: 'old',
        category: 'crowding',
        value: 'saturated',
        observedAt: new Date('2026-08-23T09:20:00.000Z'),
      }),
      vote({
        reporterId: 'recent-1',
        category: 'crowding',
        value: 'low',
        observedAt: new Date('2026-08-23T09:50:00.000Z'),
      }),
      vote({
        reporterId: 'recent-2',
        category: 'crowding',
        value: 'low',
        observedAt: new Date('2026-08-23T09:55:00.000Z'),
      }),
    ],
  });

  expect(status.crowding).toEqual({
    level: 'low',
    source: 'reported',
    label: 'Affluence faible signalée',
    reporterCount: 2,
    observedAt: '2026-08-23T09:55:00.000Z',
    expiresAt: '2026-08-23T10:35:00.000Z',
  });
});

test('report scope follows the category instead of blindly using journey context', () => {
  expect(deriveReportScope({
    stationId,
    category: 'elevatorsUnavailable',
    lineId: 'line-1',
    vehicleId: 'vehicle-1',
  })).toEqual({ kind: 'station', id: stationId });

  expect(deriveReportScope({
    stationId,
    category: 'crowding',
    lineId: 'line-1',
    vehicleId: 'vehicle-1',
  })).toEqual({ kind: 'vehicle', id: 'vehicle-1' });

  expect(deriveReportScope({
    stationId,
    category: 'pickpocket',
    lineId: 'line-1',
  })).toEqual({ kind: 'line', id: 'line-1' });
});

test('an equipment report remains a separate station incident and does not hide accessibility', () => {
  const status = resolveStationStatus({
    stationId,
    at: now,
    automaticAccessibility: { condition: 'autonomous', label: 'En autonomie' },
    votes: [
      vote({
        reporterId: 'user-1',
        category: 'elevatorsUnavailable',
        observedAt: new Date('2026-08-23T09:50:00.000Z'),
      }),
      vote({
        reporterId: 'user-2',
        category: 'elevatorsUnavailable',
        observedAt: new Date('2026-08-23T09:55:00.000Z'),
      }),
    ],
  });

  expect(status.accessibility?.source).toBe('automatic');
  expect(status.incidents).toContainEqual({
    category: 'elevatorsUnavailable',
    scopeKind: 'station',
    scopeId: stationId,
    state: 'active',
    label: 'Ascenseurs signalés indisponibles',
    reporterCount: 2,
    observedAt: '2026-08-23T09:55:00.000Z',
    expiresAt: '2026-08-23T11:10:00.000Z',
  });
});

test('one person keeps one current vote in every distinct incident subject', () => {
  const status = resolveStationStatus({
    stationId, at: now,
    votes: [
      vote({ reporterId: 'same-person', category: 'restroomsClosed', value: 'occurrence' }),
      vote({ reporterId: 'same-person', category: 'elevatorsUnavailable', value: 'occurrence', observedAt: minutesAgo(1) }),
    ],
  });
  expect(status.incidents.map((incident) => incident.category).sort())
    .toEqual(['elevatorsUnavailable', 'restroomsClosed']);
});

test('an exact crowding tie follows the most recent observation', () => {
  const status = resolveStationStatus({
    stationId, at: now,
    votes: [
      vote({ reporterId: 'u1', category: 'crowding', value: 'low', observedAt: minutesAgo(1) }),
      vote({ reporterId: 'u2', category: 'crowding', value: 'high', observedAt: minutesAgo(1) }),
    ],
  });
  // Same timestamp is stable by observation ordering; making high one ms newer
  // pins the product rule independently from enum order.
  const newerHigh = resolveStationStatus({
    stationId, at: now,
    votes: [
      vote({ reporterId: 'u1', category: 'crowding', value: 'low', observedAt: minutesAgo(1) }),
      vote({ reporterId: 'u2', category: 'crowding', value: 'high', observedAt: new Date(minutesAgo(1).getTime() + 1) }),
    ],
  });
  expect(status.crowding?.level).toBeDefined();
  expect(newerHigh.crowding?.level).toBe('high');
});

test('a newer line vote does not erase the same person’s station vote', () => {
  const status = resolveStationStatus({
    stationId, at: now,
    votes: [
      vote({ reporterId: 'u1', category: 'crowding', value: 'low', observedAt: minutesAgo(5) }),
      vote({ reporterId: 'u1', category: 'crowding', scopeKind: 'line', scopeId: 'line-1', value: 'high', observedAt: minutesAgo(1) }),
    ],
  });
  expect(status.crowding?.level).toBe('low');
});

test('a line-scoped safety incident is shown only in the matching context', () => {
  const votes = [vote({
    category: 'pickpocket', scopeKind: 'line', scopeId: 'line-1', value: 'occurrence',
  })];
  expect(resolveStationStatus({ stationId, at: now, votes }).incidents).toEqual([]);
  expect(resolveStationStatus({ stationId, at: now, lineId: 'line-1', votes }).incidents)
    .toHaveLength(1);
});
