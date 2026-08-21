import { expect, test } from 'bun:test';

import { compactParisDateTime, formatParisLongDate, formatParisTime } from './index';

test('times format on the Paris clock', () => {
  expect(formatParisTime('2026-08-12T16:05:00.000Z')).toBe('18 h 05');
  expect(formatParisTime('2026-08-12T16:05:00.000Z', 'h')).toBe('18h05');
});

test('long dates format on the Paris calendar', () => {
  expect(formatParisLongDate('2026-08-12T16:05:00.000Z')).toBe('mercredi 12 août');
});

test('compact datetimes use the Paris wall clock', () => {
  expect(compactParisDateTime(new Date('2026-08-12T21:50:30Z'))).toBe('20260812T235030');
});
