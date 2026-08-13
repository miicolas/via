import { expect, test } from 'bun:test';

import { isNearWhite } from '@/lib/is-near-white';
import { withAlpha } from '@/lib/with-alpha';

test('alpha is appended as a hex channel', () => {
  expect(withAlpha('#8D5E2A', 0.22)).toBe('#8D5E2A38');
  expect(withAlpha('#fff', 1)).toBe('#ffffffFF');
});

test('alpha stays inside its range', () => {
  expect(withAlpha('#000000', -1)).toBe('#00000000');
  expect(withAlpha('#000000', 4)).toBe('#000000FF');
});

test('only near-white fills need an outline', () => {
  expect(isNearWhite('#FFFFFF')).toBe(true);
  expect(isNearWhite('#8D5E2A')).toBe(false);
  expect(isNearWhite('#CF009E')).toBe(false);
});
