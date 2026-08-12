import { expect, test } from 'bun:test';

import { buildBanSearchUrl } from './ban-client';

test('limits BAN address searches to Île-de-France', () => {
  const url = buildBanSearchUrl('rue de la république', { limit: 5 });

  expect(url.searchParams.get('depcode')).toBe('75,77,78,91,92,93,94,95');
});

test('keeps the origin for geographic ranking', () => {
  const url = buildBanSearchUrl('rue de la république', {
    limit: 5,
    origin: { latitude: 48.8566, longitude: 2.3522 },
  });

  expect(url.searchParams.get('lat')).toBe('48.8566');
  expect(url.searchParams.get('lon')).toBe('2.3522');
});
