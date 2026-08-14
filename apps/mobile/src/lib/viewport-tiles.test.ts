import { expect, test } from 'bun:test';

import { tileBounds, tilesForRegion, TILE_SIZE_DEGREES } from './viewport-tiles';

const parisViewport = {
  latitude: 48.8566,
  longitude: 2.3522,
  latitudeDelta: 0.01,
  longitudeDelta: 0.01,
};

test('covers the whole viewport, edges included', () => {
  const keys = tilesForRegion(parisViewport);

  for (const key of keys) {
    const bounds = tileBounds(key);
    expect(bounds.maxLatitude - bounds.minLatitude).toBeCloseTo(TILE_SIZE_DEGREES);
    expect(bounds.maxLongitude - bounds.minLongitude).toBeCloseTo(TILE_SIZE_DEGREES);
  }

  // Every viewport corner falls inside some returned tile.
  const south = parisViewport.latitude - parisViewport.latitudeDelta / 2;
  const north = parisViewport.latitude + parisViewport.latitudeDelta / 2;
  const west = parisViewport.longitude - parisViewport.longitudeDelta / 2;
  const east = parisViewport.longitude + parisViewport.longitudeDelta / 2;
  for (const [latitude, longitude] of [
    [south, west],
    [south, east],
    [north, west],
    [north, east],
  ] as const) {
    expect(
      keys.some((key) => {
        const bounds = tileBounds(key);
        return (
          latitude >= bounds.minLatitude &&
          latitude <= bounds.maxLatitude &&
          longitude >= bounds.minLongitude &&
          longitude <= bounds.maxLongitude
        );
      })
    ).toBe(true);
  }
});

test('the same neighbourhood always quantizes to the same keys', () => {
  const nudged = {
    ...parisViewport,
    latitude: parisViewport.latitude + 0.0004,
    longitude: parisViewport.longitude - 0.0004,
  };

  expect(tilesForRegion(nudged)).toEqual(tilesForRegion(parisViewport));
});

test('a marker-zoom viewport needs only a handful of tiles', () => {
  expect(tilesForRegion(parisViewport).length).toBeLessThanOrEqual(4);
});

test('tiles work across the negative-longitude side of the meridian', () => {
  const keys = tilesForRegion({ ...parisViewport, longitude: -0.01 });
  for (const key of keys) {
    const bounds = tileBounds(key);
    expect(bounds.minLongitude).toBeLessThan(bounds.maxLongitude);
  }
});
