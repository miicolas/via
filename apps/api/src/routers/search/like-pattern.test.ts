import { expect, test } from 'bun:test';

import { escapeLikePattern } from './like-pattern';

test('plain text passes through', () => {
  expect(escapeLikePattern('république')).toBe('république');
});

test('LIKE operators are escaped', () => {
  expect(escapeLikePattern('12%')).toBe('12\\%');
  expect(escapeLikePattern('a_b')).toBe('a\\_b');
});

test('the escape character itself is escaped', () => {
  expect(escapeLikePattern('a\\b')).toBe('a\\\\b');
});
