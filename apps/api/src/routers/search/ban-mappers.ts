import type { AddressSearchResult } from '@via/contract';

import type { BanFeature } from './ban-client';

/**
 * BAN speaks GeoJSON, so `coordinates` is `[longitude, latitude]` — the flip to
 * `{ latitude, longitude }` happens here and nowhere else, the same rule
 * `geo/coordinates.ts` states. Features missing a field are dropped rather
 * than crashing the whole response: the geocoder's output is not ours to trust.
 */
export function toAddressResults(features: BanFeature[]): AddressSearchResult[] {
  return features.flatMap((feature) => {
    const { geometry, properties } = feature;
    const coordinates = Array.isArray(geometry?.coordinates) ? geometry.coordinates : [];
    const [longitude, latitude] = coordinates as [unknown, unknown];
    const { id, name, postcode, city } = properties ?? {};

    if (
      typeof longitude !== 'number' ||
      typeof latitude !== 'number' ||
      typeof id !== 'string' ||
      typeof name !== 'string' ||
      typeof postcode !== 'string' ||
      typeof city !== 'string'
    ) {
      return [];
    }

    return [
      {
        kind: 'address' as const,
        id,
        name,
        context: `${postcode} ${city}`,
        coordinate: { latitude, longitude },
      },
    ];
  });
}

/**
 * The planner has no separate municipality destination kind, so a commune
 * centre keeps the address-shaped contract while remaining identifiable to the
 * server-side place resolver.
 */
export function toMunicipalityResults(features: BanFeature[]): AddressSearchResult[] {
  return toAddressResults(
    features.filter(({ properties }) => properties?.type === 'municipality')
  );
}
