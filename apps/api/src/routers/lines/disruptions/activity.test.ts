import { expect, test } from 'bun:test';

import { activityOf, UPCOMING_HORIZON_SECONDS } from './activity';

const now = 1_000_000;
const hour = 3_600;

test('a period containing now is active', () => {
  expect(activityOf([{ beginsAt: now - hour, endsAt: now + hour }], now)).toEqual({
    kind: 'active',
  });
});

test('period bounds are inclusive on both ends', () => {
  expect(activityOf([{ beginsAt: now, endsAt: now + hour }], now)).toEqual({ kind: 'active' });
  expect(activityOf([{ beginsAt: now - hour, endsAt: now }], now)).toEqual({ kind: 'active' });
});

test('the earliest start within the horizon wins for upcoming', () => {
  const activity = activityOf(
    [
      { beginsAt: now + 5 * hour, endsAt: now + 6 * hour },
      { beginsAt: now + 2 * hour, endsAt: now + 3 * hour },
    ],
    now
  );
  expect(activity).toEqual({ kind: 'upcoming', beginsAt: now + 2 * hour });
});

test('an active period beats any upcoming one', () => {
  const activity = activityOf(
    [
      { beginsAt: now + 2 * hour, endsAt: now + 3 * hour },
      { beginsAt: now - hour, endsAt: now + hour },
    ],
    now
  );
  expect(activity).toEqual({ kind: 'active' });
});

test('past periods and starts beyond the horizon are inactive', () => {
  expect(activityOf([{ beginsAt: now - 2 * hour, endsAt: now - hour }], now)).toEqual({
    kind: 'inactive',
  });
  expect(
    activityOf(
      [{ beginsAt: now + UPCOMING_HORIZON_SECONDS + 1, endsAt: now + UPCOMING_HORIZON_SECONDS + hour }],
      now
    )
  ).toEqual({ kind: 'inactive' });
});

test('no periods means inactive', () => {
  expect(activityOf([], now)).toEqual({ kind: 'inactive' });
});
