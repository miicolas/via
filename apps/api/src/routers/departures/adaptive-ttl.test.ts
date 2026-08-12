import { expect, test } from 'bun:test';

import { adaptiveTtlSeconds } from './adaptive-ttl';

test('on-pace spending keeps the base freshness', () => {
  expect(adaptiveTtlSeconds(0.4)).toBe(120);
  expect(adaptiveTtlSeconds(1)).toBe(120);
});

test('burning ahead of pace doubles then quadruples the TTL', () => {
  expect(adaptiveTtlSeconds(1.2)).toBe(240);
  expect(adaptiveTtlSeconds(2.5)).toBe(480);
});
