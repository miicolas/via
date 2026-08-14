import type { NetworkRoute } from '@via/contract';
import { describe, expect, test } from 'bun:test';

import {
  alignLineWithRouteLayout,
  positionTransitRoutes,
  prepareTransitRouteLayout,
} from './transit-map-layout';

const VIEWPORT = {
  latitudeDelta: 0.01,
  longitudeDelta: 0.01,
  width: 1_000,
  height: 1_000,
};

function route(
  id: string,
  coordinates: Array<{ latitude: number; longitude: number }>
): NetworkRoute {
  return {
    id,
    shortName: id,
    color: id === 'A' ? '#FF0000' : '#0000FF',
    textColor: '#FFFFFF',
    mode: 'metro',
    segments: [{ id: `${id}-segment`, coordinates }],
  };
}

const SHARED_TRACK = [
  { latitude: 48.85, longitude: 2.34 },
  { latitude: 48.85, longitude: 2.35 },
  { latitude: 48.85, longitude: 2.36 },
];

describe('transit route layout', () => {
  test('turns the same track into one adjacent lane per route', () => {
    const routes = [route('A', SHARED_TRACK), route('B', SHARED_TRACK.toReversed())];

    const positioned = positionTransitRoutes(prepareTransitRouteLayout(routes), VIEWPORT);
    const firstMiddle = positioned[0].segments[0].coordinates[1]!;
    const secondMiddle = positioned[1].segments[0].coordinates[1]!;
    const separationPixels =
      (Math.abs(firstMiddle.latitude - secondMiddle.latitude) / VIEWPORT.latitudeDelta) *
      VIEWPORT.height;

    expect(separationPixels).toBeCloseTo(6, 4);
    expect((firstMiddle.latitude + secondMiddle.latitude) / 2).toBeCloseTo(48.85, 8);
    expect(firstMiddle.latitude).not.toBe(secondMiddle.latitude);
  });

  test('gives every route a distinct lane when three routes share a track', () => {
    const routes = [
      route('A', SHARED_TRACK),
      route('B', SHARED_TRACK.toReversed()),
      route('C', SHARED_TRACK),
    ];

    const positioned = positionTransitRoutes(prepareTransitRouteLayout(routes), VIEWPORT);
    const latitudes = positioned
      .map((positionedRoute) => positionedRoute.segments[0].coordinates[1]!.latitude)
      .toSorted((first, second) => first - second);
    const laneGaps = latitudes.slice(1).map(
      (latitude, index) =>
        ((latitude - latitudes[index]!) / VIEWPORT.latitudeDelta) * VIEWPORT.height
    );

    expect(new Set(latitudes).size).toBe(3);
    for (const gap of laneGaps) expect(gap).toBeCloseTo(6, 4);
    expect(latitudes[1]).toBeCloseTo(48.85, 8);
  });

  test('leaves a route that does not share a corridor on its source geometry', () => {
    const separateTrack = SHARED_TRACK.map((coordinate) => ({
      ...coordinate,
      latitude: coordinate.latitude + 0.01,
    }));
    const separate = route('C', separateTrack);

    const positioned = positionTransitRoutes(
      prepareTransitRouteLayout([route('A', SHARED_TRACK), separate]),
      VIEWPORT
    );

    expect(positioned[1]).toEqual(separate);
  });

  test('does not create a lane for a short parallel brush at an intersection', () => {
    const shortTrack = [
      { latitude: 48.85, longitude: 2.3497 },
      { latitude: 48.85, longitude: 2.3503 },
    ];
    const short = route('B', shortTrack);

    const positioned = positionTransitRoutes(
      prepareTransitRouteLayout([route('A', SHARED_TRACK), short]),
      VIEWPORT
    );

    expect(positioned[1]).toEqual(short);
  });

  test('keeps a focused station on its route after that route moves into a lane', () => {
    const lines = [route('A', SHARED_TRACK), route('B', SHARED_TRACK.toReversed())];
    const positioned = positionTransitRoutes(prepareTransitRouteLayout(lines), VIEWPORT);
    const line = {
      route: lines[0],
      interchangeCount: 0,
      stations: [
        {
          id: 'station',
          name: 'Station',
          coordinate: SHARED_TRACK[1]!,
          routeIds: ['A'],
        },
      ],
    };

    const aligned = alignLineWithRouteLayout(line, positioned)!;

    expect(aligned.route).toBe(positioned[0]);
    expect(aligned.stations[0]!.coordinate).toEqual(
      positioned[0].segments[0].coordinates[1]
    );
  });
});
