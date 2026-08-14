import { expect, test } from 'bun:test';
import type { JourneySection } from '@via/contract';

import { journeySectionCoordinates } from './journey-map-geometry';

const section = (geometry: JourneySection['geometry']): JourneySection => ({
  type: 'walk',
  durationSeconds: 60,
  from: { name: 'Départ', coordinate: { latitude: 48.8566, longitude: 2.3522 } },
  to: { name: 'Arrivée', coordinate: { latitude: 48.8595, longitude: 2.3707 } },
  geometry,
  stops: [],
});

test('uses the routed section geometry when it exists', () => {
  const geometry = [
    { latitude: 48.8566, longitude: 2.3522 },
    { latitude: 48.8574, longitude: 2.356 },
    { latitude: 48.8595, longitude: 2.3707 },
  ];

  expect(journeySectionCoordinates(section(geometry))).toBe(geometry);
});

test('falls back to section endpoints when the provider has no geometry', () => {
  expect(journeySectionCoordinates(section([]))).toEqual([
    { latitude: 48.8566, longitude: 2.3522 },
    { latitude: 48.8595, longitude: 2.3707 },
  ]);
});
