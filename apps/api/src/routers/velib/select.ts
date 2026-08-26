import type {
  BikeStation,
  BikeStationSearchResult,
  Coordinate,
  StationsInAreaInput,
} from '@via/contract';

import { selectInArea } from '../../geo/area';
import { haversineMeters } from '../../geo/distance';

export function selectBikeStationsInArea(
  stations: BikeStation[],
  area: StationsInAreaInput
): BikeStation[] {
  return selectInArea(stations, area);
}

/**
 * The snapshot is one shared array that only changes every 55 s, so its search
 * index is built once per snapshot rather than once per keystroke.
 */
const searchIndexes = new WeakMap<BikeStation[], IndexedBikeStation[]>();

type IndexedBikeStation = { station: BikeStation; name: string };

function searchIndex(stations: BikeStation[]): IndexedBikeStation[] {
  const cached = searchIndexes.get(stations);
  if (cached) return cached;

  const index = stations.map((station) => ({ station, name: normalized(station.name) }));
  searchIndexes.set(stations, index);
  return index;
}

export function selectMatchingBikeStations(
  stations: BikeStation[],
  query: string,
  limit: number,
  origin?: Coordinate
): BikeStationSearchResult[] {
  const needle = normalized(query);
  return searchIndex(stations)
    .filter(({ name }) => name.includes(needle))
    .sort((lhs, rhs) => {
      const prefix = Number(rhs.name.startsWith(needle)) - Number(lhs.name.startsWith(needle));
      if (prefix !== 0) return prefix;
      const occurrence = lhs.name.indexOf(needle) - rhs.name.indexOf(needle);
      if (occurrence !== 0) return occurrence;
      if (origin) {
        const distance = haversineMeters(origin, lhs.station.coordinate)
          - haversineMeters(origin, rhs.station.coordinate);
        if (distance !== 0) return distance;
      }
      return lhs.station.name.localeCompare(rhs.station.name, 'fr', { sensitivity: 'base' });
    })
    .slice(0, limit)
    .map(({ station }) => ({
      kind: 'bikeStation' as const,
      id: station.id,
      name: station.name,
      coordinate: station.coordinate,
      capacity: station.capacity,
      ...(station.availability ? { availability: station.availability } : {}),
    }));
}

function normalized(value: string) {
  return value
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLocaleLowerCase('fr');
}
