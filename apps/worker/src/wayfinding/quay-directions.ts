import type { LonLat } from '@via/db/schema';

/**
 * Which direction does a referential quay serve?
 *
 * The wayfinding dataset keys RER advice by quays of the `arrets` referential —
 * ids the GTFS never uses and the planner never returns. The referential knows
 * where a quay *is* but not which way its trains run, so the direction is
 * recovered from the advice itself: "exit X is at carriage 2 of 10" places that
 * exit near the head of the train, and the head points the way the train
 * travels. Projecting the exit onto the line's track therefore tells us, for
 * each candidate direction, whether the dataset's carriage number is on the
 * right side of the platform. Rows too close to the middle of the train or to
 * the middle of the platform abstain; a quay is resolved only when every vote
 * agrees.
 */

export type TravelVector = {
  directionId: number;
  /** Unit vector of travel at the station, in metres east/north. */
  east: number;
  north: number;
};

export type QuayDirectionAdvice = {
  car: number;
  carCount: number;
  exitLocation: LonLat;
};

/** Carriages this close to the middle of the train say nothing about the head. */
const MIN_CAR_OFFSET = 1.5;
/** Exits this close to the platform centre say nothing about the track ends. */
const MIN_ALONG_TRACK_METERS = 30;

const METERS_PER_DEGREE_LATITUDE = 111_320;

/** Equirectangular offset in metres — station-scale distances, centimetre error. */
export function metersEastNorth(from: LonLat, to: LonLat) {
  const latitudeRadians = (from.lat * Math.PI) / 180;
  return {
    east: (to.lon - from.lon) * METERS_PER_DEGREE_LATITUDE * Math.cos(latitudeRadians),
    north: (to.lat - from.lat) * METERS_PER_DEGREE_LATITUDE,
  };
}

export type InferQuayDirectionOptions = {
  stationLocation: LonLat;
  travelVectors: readonly TravelVector[];
  advice: readonly QuayDirectionAdvice[];
};

export function inferQuayDirection({
  stationLocation,
  travelVectors,
  advice,
}: InferQuayDirectionOptions) {
  const votes = new Map<number, number>();
  for (const row of advice) {
    // Negative offset: the carriage is in the front half, so the exit sits
    // ahead of the platform centre along the direction of travel.
    const carOffset = row.car - (row.carCount + 1) / 2;
    if (Math.abs(carOffset) < MIN_CAR_OFFSET) continue;
    const exitOffset = metersEastNorth(stationLocation, row.exitLocation);

    for (const vector of travelVectors) {
      const alongTrack = exitOffset.east * vector.east + exitOffset.north * vector.north;
      if (Math.abs(alongTrack) < MIN_ALONG_TRACK_METERS) continue;
      if (alongTrack > 0 === carOffset < 0) {
        votes.set(vector.directionId, (votes.get(vector.directionId) ?? 0) + 1);
      }
    }
  }

  const ranked = [...votes.entries()].sort((a, b) => b[1] - a[1]);
  if (ranked.length !== 1) return undefined;
  return ranked[0]![0];
}
