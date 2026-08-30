import { expect, test } from 'bun:test';

import { boundGroups, rankStopTimeCandidates } from './stop-time-candidates';

test('a frontier reached at one moment stays a single query', () => {
  const stops = [
    { stopId: 'a', bound: 36_000 },
    { stopId: 'b', bound: 36_120 },
    { stopId: 'c', bound: 36_200 },
  ];

  expect(boundGroups('board', stops)).toEqual([
    { stopIds: ['a', 'b', 'c'], bound: 36_000 },
  ]);
});

test('a frontier spread over a whole leg is split so the far stops keep a budget', () => {
  const near = Array.from({ length: 6 }, (_, index) => ({
    stopId: `near-${index}`,
    bound: 36_000 + index * 10,
  }));
  const far = { stopId: 'far', bound: 38_400 };

  const groups = boundGroups('board', [far, ...near]);

  expect(groups.length).toBeGreaterThan(1);
  const farGroup = groups.find((group) => group.stopIds.includes(far.stopId));
  expect(farGroup?.bound).toBe(far.bound);
  expect(farGroup?.stopIds).toEqual([far.stopId]);
});

test('an arrival search groups backwards from the latest bound', () => {
  const groups = boundGroups('alight', [
    { stopId: 'early', bound: 36_000 },
    { stopId: 'late', bound: 38_400 },
  ]);

  expect(groups[0]).toEqual({ stopIds: ['late'], bound: 38_400 });
  expect(groups[1]).toEqual({ stopIds: ['early'], bound: 36_000 });
});

test('never exceeds the query ceiling however wide the frontier is', () => {
  const stops = Array.from({ length: 400 }, (_, index) => ({
    stopId: `stop-${index}`,
    bound: 36_000 + index * 60,
  }));

  expect(boundGroups('board', stops).length).toBeLessThanOrEqual(4);
});

test('the candidate cap trims by waiting time, not by the clock', () => {
  const serviceDate = '2026-08-27';
  const near = Array.from({ length: 4 }, (_, index) => ({
    tripId: `bus-${index}`,
    stopId: 'near',
    seconds: 36_060 + index * 60,
    serviceDate,
  }));
  const far = { tripId: 'rer', stopId: 'far', seconds: 38_460, serviceDate };
  const bounds = new Map([
    ['near', 36_000],
    ['far', 38_400],
  ]);

  const ranked = rankStopTimeCandidates(
    'board',
    [...near, far],
    (stopId) => bounds.get(stopId),
    2
  );

  // The train an hour away is one minute of waiting: it outranks every bus but
  // the one leaving at the same instant the traveller reaches its stop.
  expect(ranked.map((candidate) => candidate.tripId)).toEqual(['bus-0', 'rer']);
});

test('drops a candidate the shared query returned from before its own stop bound', () => {
  const serviceDate = '2026-08-27';
  const ranked = rankStopTimeCandidates(
    'board',
    [
      { tripId: 'too-early', stopId: 'far', seconds: 36_060, serviceDate },
      { tripId: 'boardable', stopId: 'far', seconds: 38_460, serviceDate },
    ],
    () => 38_400
  );

  expect(ranked.map((candidate) => candidate.tripId)).toEqual(['boardable']);
});

test('an arrival candidate is ranked by how long the traveller waits before it', () => {
  const serviceDate = '2026-08-27';
  const ranked = rankStopTimeCandidates(
    'alight',
    [
      { tripId: 'late', stopId: 'exit', seconds: 38_500, serviceDate },
      { tripId: 'usable', stopId: 'exit', seconds: 38_340, serviceDate },
    ],
    () => 38_400
  );

  expect(ranked.map((candidate) => candidate.tripId)).toEqual(['usable']);
});
