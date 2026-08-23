import { describe, expect, test } from 'bun:test';

import { yesterdayIsSearchable } from './loader';
import { UNKNOWN_TIMETABLE_HORIZON } from './timetable-horizon';

/** What the current IDFM feed measures: the last call lands at 32:00. */
const IDFM_HORIZON = 32 * 3_600;

const at = (hours: number) => hours * 3_600;

describe('yesterdayIsSearchable', () => {
  test('keeps yesterday in the small hours, when its night service is still running', () => {
    // 01:00 today is 25:00 in yesterday's frame — well inside a 32:00 feed.
    expect(yesterdayIsSearchable('board', at(1), IDFM_HORIZON)).toBe(true);
  });

  test('keeps yesterday right up to the horizon', () => {
    // 08:00 today is exactly 32:00 yesterday: the last second that can match.
    expect(yesterdayIsSearchable('board', at(8), IDFM_HORIZON)).toBe(true);
  });

  test('drops yesterday one second past the horizon', () => {
    expect(yesterdayIsSearchable('board', at(8) + 1, IDFM_HORIZON)).toBe(false);
  });

  test('drops yesterday for the rest of the day', () => {
    for (const hour of [9, 12, 14, 18, 23]) {
      expect(yesterdayIsSearchable('board', at(hour), IDFM_HORIZON)).toBe(false);
    }
  });

  test('never drops yesterday when the horizon is unknown', () => {
    // A database that predates the importer writing the key must behave
    // exactly as it did before: search both service days, always.
    for (const hour of [0, 8, 14, 23]) {
      expect(yesterdayIsSearchable('board', at(hour), UNKNOWN_TIMETABLE_HORIZON)).toBe(true);
    }
  });

  test('never drops yesterday on the backward pass', () => {
    // `alight` filters `secs <= bound + 86 400`, which stays satisfiable however
    // late the bound is, so the horizon says nothing about it.
    for (const hour of [0, 8, 14, 23]) {
      expect(yesterdayIsSearchable('alight', at(hour), IDFM_HORIZON)).toBe(true);
    }
  });

  test('a feed running later into the night keeps yesterday later', () => {
    const nightBus = 38 * 3_600;
    expect(yesterdayIsSearchable('board', at(13), nightBus)).toBe(true);
    expect(yesterdayIsSearchable('board', at(15), nightBus)).toBe(false);
  });

  test('a feed that never passes midnight drops yesterday outright', () => {
    const noNightService = 24 * 3_600;
    expect(yesterdayIsSearchable('board', 0, noNightService)).toBe(true);
    expect(yesterdayIsSearchable('board', 1, noNightService)).toBe(false);
  });
});
