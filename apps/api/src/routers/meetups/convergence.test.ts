import { describe, expect, test } from 'bun:test';

import { meetupPlanSchema, type Journey, type JourneySection, type MeetupPlan, type MeetupStation } from '@via/contract';

import { buildConvergencePlan, stalePlan } from './convergence';

const station = (id: string, name = id): MeetupStation => ({
  id,
  name,
  coordinate: { latitude: 48.85, longitude: 2.35 },
});

const transit = ({
  id,
  serviceId,
  from,
  to,
  departureAt,
  arrivalAt,
  stops,
  zone = 'middle',
}: {
  id: string;
  serviceId: string;
  from: string;
  to: string;
  departureAt: string;
  arrivalAt: string;
  stops: Array<{ id: string; at: string }>;
  zone?: 'front' | 'middle' | 'rear';
}): JourneySection => ({
  id,
  type: 'transit',
  durationSeconds: (Date.parse(arrivalAt) - Date.parse(departureAt)) / 1_000,
  from: { name: from, coordinate: station(from).coordinate },
  to: { name: to, coordinate: station(to).coordinate },
  departureAt,
  arrivalAt,
  geometry: [],
  route: {
    id: 'rer-a',
    shortName: 'A',
    longName: 'RER A',
    mode: 'rer',
    color: '#e2231a',
    textColor: '#ffffff',
  },
  direction: 'Destination',
  serviceId,
  stops: stops.map(({ id: stopId, at }) => ({
    id: `stop:${stopId}`,
    stationId: stopId,
    name: stopId,
    coordinate: station(stopId).coordinate,
    arrivalAt: at,
    departureAt: at,
  })),
  boardingPosition: {
    car: zone === 'front' ? 1 : zone === 'rear' ? 8 : 4,
    carCount: 8,
    zone,
    reason: 'transfer',
  },
});

const journey = (id: string, sections: JourneySection[]): Journey => {
  const departureAt = sections[0]?.departureAt ?? '2026-08-30T18:00:00+02:00';
  const arrivalAt = sections.at(-1)?.arrivalAt ?? '2026-08-30T19:00:00+02:00';
  return {
    id,
    qualifier: 'recommended',
    durationSeconds: (Date.parse(arrivalAt) - Date.parse(departureAt)) / 1_000,
    walkingDurationSeconds: 0,
    transferCount: Math.max(0, sections.length - 1),
    departureAt,
    arrivalAt,
    status: 'normal',
    warnings: [],
    sections,
  };
};

describe('buildConvergencePlan', () => {
  test('forms a group progressively on verified services', () => {
    const s1Alice = transit({
      id: 'alice-s1',
      serviceId: 'service:s1',
      from: 'A',
      to: 'J2',
      departureAt: '2026-08-30T18:10:00+02:00',
      arrivalAt: '2026-08-30T18:32:00+02:00',
      stops: [
        { id: 'A', at: '2026-08-30T18:10:00+02:00' },
        { id: 'J1', at: '2026-08-30T18:20:00+02:00' },
        { id: 'J2', at: '2026-08-30T18:32:00+02:00' },
      ],
      zone: 'front',
    });
    const s1Bob = transit({
      id: 'bob-s1',
      serviceId: 'service:s1',
      from: 'J1',
      to: 'J2',
      departureAt: '2026-08-30T18:20:00+02:00',
      arrivalAt: '2026-08-30T18:32:00+02:00',
      stops: [
        { id: 'J1', at: '2026-08-30T18:20:00+02:00' },
        { id: 'J2', at: '2026-08-30T18:32:00+02:00' },
      ],
      zone: 'front',
    });
    const s2 = (owner: string) => transit({
      id: `${owner}-s2`,
      serviceId: 'service:s2',
      from: 'J2',
      to: 'C',
      departureAt: '2026-08-30T18:35:00+02:00',
      arrivalAt: '2026-08-30T18:55:00+02:00',
      stops: [
        { id: 'J2', at: '2026-08-30T18:35:00+02:00' },
        { id: 'C', at: '2026-08-30T18:55:00+02:00' },
      ],
      zone: 'rear',
    });

    const plan = buildConvergencePlan({
      participants: [
        { participantId: '11111111-1111-4111-8111-111111111111', journeys: [journey('alice', [s1Alice, s2('alice')])] },
        { participantId: '22222222-2222-4222-8222-222222222222', journeys: [journey('bob', [s1Bob, s2('bob')])] },
        { participantId: '33333333-3333-4333-8333-333333333333', journeys: [journey('chloe', [s2('chloe')])] },
      ],
      destination: station('C'),
      targetArrivalAt: new Date('2026-08-30T19:00:00+02:00'),
      generatedAt: new Date('2026-08-29T12:00:00+02:00'),
      revision: 4,
    });

    expect(plan.status).toBe('ready');
    expect(plan.joinPoints.map((point) => ({
      station: point.station.id,
      service: point.serviceId,
      participants: point.participantIds,
      zone: point.zone,
    }))).toEqual([
      {
        station: 'J1',
        service: 'service:s1',
        participants: [
          '11111111-1111-4111-8111-111111111111',
          '22222222-2222-4222-8222-222222222222',
        ],
        zone: 'front',
      },
      {
        station: 'J2',
        service: 'service:s2',
        participants: [
          '11111111-1111-4111-8111-111111111111',
          '22222222-2222-4222-8222-222222222222',
          '33333333-3333-4333-8333-333333333333',
        ],
        zone: 'rear',
      },
    ]);
  });

  test('does not infer the same train from a shared line and time', () => {
    const alice = transit({
      id: 'alice', serviceId: 'vehicle:one', from: 'A', to: 'C',
      departureAt: '2026-08-30T18:20:00+02:00', arrivalAt: '2026-08-30T18:50:00+02:00',
      stops: [{ id: 'J1', at: '2026-08-30T18:30:00+02:00' }, { id: 'C', at: '2026-08-30T18:50:00+02:00' }],
    });
    const bob = transit({
      id: 'bob', serviceId: 'vehicle:two', from: 'B', to: 'C',
      departureAt: '2026-08-30T18:20:00+02:00', arrivalAt: '2026-08-30T18:50:00+02:00',
      stops: [{ id: 'J1', at: '2026-08-30T18:30:00+02:00' }, { id: 'C', at: '2026-08-30T18:50:00+02:00' }],
    });

    const plan = buildConvergencePlan({
      participants: [
        { participantId: '11111111-1111-4111-8111-111111111111', journeys: [journey('alice', [alice])] },
        { participantId: '22222222-2222-4222-8222-222222222222', journeys: [journey('bob', [bob])] },
      ],
      destination: station('C'),
      targetArrivalAt: new Date('2026-08-30T19:00:00+02:00'),
      generatedAt: new Date('2026-08-29T12:00:00+02:00'),
      revision: 1,
    });

    expect(plan.status).toBe('fallbackAtDestination');
    expect(plan.joinPoints).toEqual([]);
  });

  test('finds a reliable two-person subgroup even when a third rider uses the same service elsewhere', () => {
    const shared = (owner: string, stops: Array<{ id: string; at: string }>) => transit({
      id: owner,
      serviceId: 'vehicle:shared',
      from: stops[0]!.id,
      to: stops.at(-1)!.id,
      departureAt: stops[0]!.at,
      arrivalAt: stops.at(-1)!.at,
      stops,
    });
    const aliceStops = [
      { id: 'A', at: '2026-08-30T18:10:00+02:00' },
      { id: 'J1', at: '2026-08-30T18:20:00+02:00' },
      { id: 'C', at: '2026-08-30T18:50:00+02:00' },
    ];
    const bobStops = [
      { id: 'J1', at: '2026-08-30T18:20:00+02:00' },
      { id: 'C', at: '2026-08-30T18:50:00+02:00' },
    ];
    const chloeStops = [
      { id: 'X', at: '2026-08-30T18:05:00+02:00' },
      { id: 'Y', at: '2026-08-30T18:15:00+02:00' },
    ];

    const plan = buildConvergencePlan({
      participants: [
        { participantId: '11111111-1111-4111-8111-111111111111', journeys: [journey('alice', [shared('alice', aliceStops)])] },
        { participantId: '22222222-2222-4222-8222-222222222222', journeys: [journey('bob', [shared('bob', bobStops)])] },
        { participantId: '33333333-3333-4333-8333-333333333333', journeys: [journey('chloe', [shared('chloe', chloeStops)])] },
      ],
      destination: station('C'),
      targetArrivalAt: new Date('2026-08-30T19:00:00+02:00'),
      generatedAt: new Date('2026-08-29T12:00:00+02:00'),
      revision: 2,
    });

    expect(plan.joinPoints).toHaveLength(1);
    expect(plan.joinPoints[0]?.station.id).toBe('J1');
    expect(plan.joinPoints[0]?.participantIds).toEqual([
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222',
    ]);
  });
});

describe('stalePlan', () => {
  const previous: MeetupPlan = {
    revision: 4,
    status: 'ready',
    generatedAt: '2026-08-29T12:00:00.000Z',
    isStale: false,
    participantJourneys: [{
      participantId: '11111111-1111-4111-8111-111111111111',
      departureAt: '2026-08-30T18:10:00+02:00',
      arrivalAt: '2026-08-30T18:55:00+02:00',
    }],
    joinPoints: [],
  };

  test('keeps the previous plan, restamps the revision and words the wait', () => {
    const kept = stalePlan(previous, 7);

    expect(kept.revision).toBe(7);
    expect(kept.isStale).toBe(true);
    expect(kept.warning).toBe('Dernier plan conservé, nouveau calcul en attente.');
    expect(kept.status).toBe(previous.status);
    expect(kept.generatedAt).toBe(previous.generatedAt);
    expect(kept.participantJourneys).toEqual(previous.participantJourneys);
    expect(kept.joinPoints).toEqual(previous.joinPoints);
    expect(previous.isStale).toBe(false);
    expect(meetupPlanSchema.parse(kept)).toEqual(kept);
  });

  test('marking an already stale plan again only moves the revision', () => {
    const once = stalePlan(previous, 5);
    const twice = stalePlan(once, 6);

    expect(twice).toEqual({ ...once, revision: 6 });
  });
});
