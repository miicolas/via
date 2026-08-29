import type { StationFountains } from '@via/contract';

type FountainCondition = 'available' | 'unavailable';

/** Turns the persisted verdict into the one French station-detail presentation. */
export function toStationFountains(
  condition: FountainCondition,
  detail: string | null
): StationFountains {
  return {
    status: condition,
    label: condition === 'available'
      ? 'Fontaine d’eau potable à proximité'
      : 'Fontaine d’eau signalée indisponible',
    ...(detail ? { detail } : {}),
  };
}
