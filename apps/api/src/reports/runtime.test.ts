import { expect, test } from 'bun:test';

import { reportRetentionCutoff } from './runtime';

test('report history is retained for exactly seven days', () => {
  expect(reportRetentionCutoff(new Date('2026-08-23T12:00:00Z')).toISOString())
    .toBe('2026-08-16T12:00:00.000Z');
});
