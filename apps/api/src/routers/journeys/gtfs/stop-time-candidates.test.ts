import { expect, test } from 'bun:test';

import { boundGroups, rankStopTimeCandidates } from './stop-time-candidates';

test('a frontier reached at one moment stays a single query', () => {
  const stops = [
    { stopKey: 1, bound: 36_000 },
    { stopKey: 2, bound: 36_120 },
    { stopKey: 3, bound: 36_200 },
  ];

  expect(boundGroups('board', stops)).toEqual([
    { stopKeys: [1, 2, 3], bound: 36_000 },
  ]);
});

test('a frontier spread over a whole leg is split so the far stops keep a budget', () => {
  const near = Array.from({ length: 6 }, (_, index) => ({
    stopKey: index + 1,
    bound: 36_000 + index * 10,
  }));
  const far = { stopKey: 99, bound: 38_400 };

  const groups = boundGroups('board', [far, ...near]);

  expect(groups.length).toBeGreaterThan(1);
  const farGroup = groups.find((group) => group.stopKeys.includes(far.stopKey));
  expect(farGroup?.bound).toBe(far.bound);
  expect(farGroup?.stopKeys).toEqual([far.stopKey]);
});

test('an arrival search groups backwards from the latest bound', () => {
  const groups = boundGroups('alight', [
    { stopKey: 1, bound: 36_000 },
    { stopKey: 2, bound: 38_400 },
  ]);

  expect(groups[0]).toEqual({ stopKeys: [2], bound: 38_400 });
  expect(groups[1]).toEqual({ stopKeys: [1], bound: 36_000 });
});

test('never exceeds the query ceiling however wide the frontier is', () => {
  const stops = Array.from({ length: 400 }, (_, index) => ({
    stopKey: index,
    bound: 36_000 + index * 60,
  }));

  expect(boundGroups('board', stops).length).toBeLessThanOrEqual(4);
});

test('the candidate cap trims by waiting time, not by the clock', () => {
  const serviceDate = '2026-08-27';
  const near = Array.from({ length: 4 }, (_, index) => ({
    tripId: `bus-${index}`,
    stopKey: 1,
    seconds: 36_060 + index * 60,
    serviceDate,
  }));
  const far = { tripId: 'rer', stopKey: 2, seconds: 38_460, serviceDate };
  const bounds = new Map([
    [1, 36_000],
    [2, 38_400],
  ]);

  const ranked = rankStopTimeCandidates(
    'board',
    [...near, far],
    (stopKey) => bounds.get(stopKey),
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
      { tripId: 'too-early', stopKey: 2, seconds: 36_060, serviceDate },
      { tripId: 'boardable', stopKey: 2, seconds: 38_460, serviceDate },
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
      { tripId: 'late', stopKey: 1, seconds: 38_500, serviceDate },
      { tripId: 'usable', stopKey: 1, seconds: 38_340, serviceDate },
    ],
    () => 38_400
  );

  expect(ranked.map((candidate) => candidate.tripId)).toEqual(['usable']);
});
