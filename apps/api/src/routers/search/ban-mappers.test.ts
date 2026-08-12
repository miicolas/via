import { expect, test } from 'bun:test';

import banSearchRivoli from './__fixtures__/ban-search-rivoli.json';
import type { BanFeature } from './ban-client';
import { toAddressResults } from './ban-mappers';

// A real Géoplateforme response for "12 rue de rivoli", captured as-is.
const features = banSearchRivoli.features as BanFeature[];

test('a real BAN response maps to address results', () => {
  const [first] = toAddressResults(features);

  expect(first).toEqual({
    kind: 'address',
    id: '75104_8249_00012',
    name: '12 Rue de Rivoli',
    context: '75004 Paris',
    // GeoJSON orders [longitude, latitude]; the mapper flips it.
    coordinate: { latitude: 48.855602, longitude: 2.35995 },
  });
});

test('malformed features are dropped, not fatal', () => {
  const malformed: BanFeature[] = [
    {},
    { geometry: { coordinates: ['2.35', '48.85'] }, properties: features[0].properties },
    { geometry: features[0].geometry, properties: { id: '75104_0000' } },
  ];

  expect(toAddressResults([...malformed, features[0]])).toHaveLength(1);
});
