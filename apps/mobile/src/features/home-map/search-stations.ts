import type { NetworkStation } from '@via/contract';

export function searchStations(stations: NetworkStation[], query: string): NetworkStation[] {
  const normalizedQuery = normalize(query.trim());
  if (!normalizedQuery) return [];

  return stations
    .map((station) => ({ station, normalizedName: normalize(station.name) }))
    .filter(({ normalizedName }) => normalizedName.includes(normalizedQuery))
    .sort((a, b) => {
      const prefixDifference =
        Number(!a.normalizedName.startsWith(normalizedQuery)) -
        Number(!b.normalizedName.startsWith(normalizedQuery));
      return prefixDifference || a.station.name.localeCompare(b.station.name, 'fr');
    })
    .slice(0, 12)
    .map(({ station }) => station);
}

function normalize(value: string) {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLocaleLowerCase('fr');
}
