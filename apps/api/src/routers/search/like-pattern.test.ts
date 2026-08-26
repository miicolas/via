import { expect, test } from 'bun:test';

import { escapeLikePattern, looseLikePattern } from './like-pattern';

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

test('a station query tolerates spaces, dashes and apostrophes between words', () => {
  expect(looseLikePattern('Gare Saint Lazare')).toBe('Gare%Saint%Lazare');
  expect(looseLikePattern('Gare Saint-Lazare')).toBe('Gare%Saint%Lazare');
  expect(looseLikePattern("Gare d’Austerlitz")).toBe('Gare%d%Austerlitz');
});

test('a loose station query still escapes LIKE operators', () => {
  expect(looseLikePattern('12% rue_de')).toBe('12\\%%rue\\_de');
});
