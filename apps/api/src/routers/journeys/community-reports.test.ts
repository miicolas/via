import { expect, test } from 'bun:test';
import type { Journey, JourneyInput, JourneysResponse } from '@via/contract';

import { applyCommunityReportVotes } from './community-reports';
import type { CurrentReportVote } from '../../reports/status-resolver';

const at = new Date('2026-08-23T10:00:00Z');
const input = {
  origin: { latitude: 48.8, longitude: 2.3 },
  destination: { kind: 'station' as const, id: 'IDFM:B', name: 'B', coordinate: { latitude: 48.9, longitude: 2.4 } },
  limit: 4,
  requiresAccessibleStations: true,
} satisfies JourneyInput;

function response(): JourneysResponse {
  const journey: Journey = {
    id: 'j1', qualifier: 'recommended', durationSeconds: 1_800, walkingDurationSeconds: 0,
    transferCount: 0, departureAt: '2026-08-23T10:10:00Z', arrivalAt: '2026-08-23T10:40:00Z',
    status: 'normal', warnings: [], sections: [{
      type: 'transit', durationSeconds: 1_800,
      from: { name: 'A', coordinate: input.origin }, to: { name: 'B', coordinate: input.destination.coordinate },
      departureAt: '2026-08-23T10:10:00Z', arrivalAt: '2026-08-23T10:40:00Z', geometry: [],
      route: { id: 'line-1', shortName: '1', longName: 'Ligne 1', mode: 'metro', color: '#000', textColor: '#fff' },
      stops: [
        { id: 'raw-a', stationId: 'IDFM:A', name: 'A', coordinate: input.origin, departureAt: '2026-08-23T10:10:00Z' },
        { id: 'raw-b', stationId: 'IDFM:B', name: 'B', coordinate: input.destination.coordinate, arrivalAt: '2026-08-23T10:40:00Z' },
      ],
    }],
  };
  return { status: 'ready', source: 'idfm-realtime', generatedAt: at.toISOString(), journeys: [journey] };
}

function pmr(reporterId: string): CurrentReportVote {
  return {
    reporterId, stationId: 'IDFM:A', category: 'wheelchairAccessUnavailable',
    scopeKind: 'station', scopeId: 'IDFM:A', value: 'occurrence', observedAt: at,
  };
}

test('one PMR report warns but two distinct reports exclude an accessible route', () => {
  const canonical = new Map([['IDFM:A', 'IDFM:A'], ['IDFM:B', 'IDFM:B']]);
  const warned = applyCommunityReportVotes(response(), input, at, [pmr('u1')], canonical);
  expect(warned.journeys[0]?.wheelchairReport).toMatchObject({ reporterCount: 1, confidence: 'observed' });

  const excluded = applyCommunityReportVotes(response(), input, at, [pmr('u1'), pmr('u2')], canonical);
  expect(excluded).toMatchObject({ status: 'no-route', reason: 'no-accessible-route', journeys: [] });
});

test('a report does not influence a passage scheduled after its expiration', () => {
  const late = response();
  late.journeys[0]!.sections[0]!.departureAt = '2026-08-23T12:00:00Z';
  late.journeys[0]!.sections[0]!.stops[0]!.departureAt = '2026-08-23T12:00:00Z';
  const result = applyCommunityReportVotes(late, input, at, [pmr('u1'), pmr('u2')], new Map([
    ['IDFM:A', 'IDFM:A'], ['IDFM:B', 'IDFM:B'],
  ]));
  expect(result.journeys).toHaveLength(1);
  expect(result.journeys[0]?.wheelchairReport).toBeUndefined();
});
