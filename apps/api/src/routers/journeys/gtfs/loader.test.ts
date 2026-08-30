import { expect, test } from 'bun:test';

import { stopKeyGroups } from './loader';

test('a stop the loader never keyed is dropped from the query, not sent unresolvable', () => {
  const groups = stopKeyGroups(
    [{ stopIds: ['known', 'unknown', 'other'], bound: 36_000 }],
    new Map([
      ['known', 1],
      ['other', 7],
    ])
  );

  expect(groups).toEqual([{ stopKeys: [1, 7], bound: 36_000 }]);
});

test('a group left with no keyed stop issues no query at all', () => {
  const groups = stopKeyGroups(
    [
      { stopIds: ['ghost'], bound: 36_000 },
      { stopIds: ['known'], bound: 38_400 },
    ],
    new Map([['known', 4]])
  );

  expect(groups).toEqual([{ stopKeys: [4], bound: 38_400 }]);
});

test('keeps every group bound with its own stops', () => {
  const groups = stopKeyGroups(
    [
      { stopIds: ['a', 'b'], bound: 36_000 },
      { stopIds: ['c'], bound: 38_400 },
    ],
    new Map([
      ['a', 1],
      ['b', 2],
      ['c', 3],
    ])
  );

  expect(groups).toEqual([
    { stopKeys: [1, 2], bound: 36_000 },
    { stopKeys: [3], bound: 38_400 },
  ]);
});
