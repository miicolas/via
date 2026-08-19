import { parseGtfsTime } from './gtfs-time';

import type { ScheduledTrip } from './import-schedules';

export type TimeProfileBuild = {
  /**
   * Index = profile id - 1. Each profile is a flat array of
   * (stopKey, arrivalOffset, departureOffset) triples in call order, offsets
   * relative to the trip's first departure.
   */
  profiles: Int32Array[];
  /** Index = trip numericId; 0 means the trip had no usable call. */
  profileKeyByTrip: Int32Array;
  /** Index = trip numericId; departure at the trip's first call. */
  startSecondsByTrip: Int32Array;
};

type BuildTimeProfilesOptions = {
  stopTimes: AsyncGenerator<Record<string, string>>;
  trips: ReadonlyMap<string, ScheduledTrip>;
  canonicalStopIdOf: (stopId: string) => string;
  stopKeyById: ReadonlyMap<string, number>;
  stopRoutePairs: Map<string, { stopId: string; routeId: string }>;
  counters: { departureCount: number; skippedStops: number };
};

/**
 * Streams `stop_times.txt` once and collapses every trip's schedule into a
 * deduplicated time profile: the vector of calls expressed relative to the
 * trip's first departure. Most trips are the same run at a different clock
 * time, so ~14.5M IDFM calls collapse into ~144k profiles — the whole build
 * fits in worker memory and the timetable shrinks ~6× on disk.
 *
 * Grouping relies on the feed listing each trip's rows contiguously; a trip
 * resurfacing after its block was flushed would silently corrupt its profile,
 * so that case throws instead.
 */
export async function buildTimeProfiles({
  stopTimes,
  trips,
  canonicalStopIdOf,
  stopKeyById,
  stopRoutePairs,
  counters,
}: BuildTimeProfilesOptions): Promise<TimeProfileBuild> {
  const profiles: Int32Array[] = [];
  const profileIdByVector = new Map<string, number>();
  const profileKeyByTrip = new Int32Array(trips.size + 1);
  const startSecondsByTrip = new Int32Array(trips.size + 1);
  const flushedTrips = new Set<number>();

  let currentTripId: string | undefined;
  let currentTrip: ScheduledTrip | undefined;
  /** Flat (stopSequence, stopKey, arrivalSeconds, departureSeconds) tuples. */
  let calls: number[] = [];

  const flush = () => {
    if (!currentTrip) return;
    flushedTrips.add(currentTrip.numericId);
    if (calls.length === 0) return;

    const callCount = calls.length / 4;
    const order = Array.from({ length: callCount }, (_, index) => index).sort(
      (a, b) => calls[a * 4] - calls[b * 4]
    );
    for (let i = 1; i < callCount; i += 1) {
      if (calls[order[i] * 4] === calls[order[i - 1] * 4]) {
        throw new Error(
          `Duplicate stop_sequence ${calls[order[i] * 4]} in stop_times.txt for trip ${currentTrip.id}`
        );
      }
    }

    const start = calls[order[0] * 4 + 3];
    const vector = new Int32Array(callCount * 3);
    for (let i = 0; i < callCount; i += 1) {
      const call = order[i] * 4;
      vector[i * 3] = calls[call + 1];
      vector[i * 3 + 1] = calls[call + 2] - start;
      vector[i * 3 + 2] = calls[call + 3] - start;
    }

    const key = vector.join(',');
    let profileId = profileIdByVector.get(key);
    if (profileId === undefined) {
      profiles.push(vector);
      profileId = profiles.length;
      profileIdByVector.set(key, profileId);
    }
    profileKeyByTrip[currentTrip.numericId] = profileId;
    startSecondsByTrip[currentTrip.numericId] = start;
  };

  for await (const stopTime of stopTimes) {
    if (stopTime.trip_id !== currentTripId) {
      flush();
      calls = [];
      currentTripId = stopTime.trip_id;
      currentTrip = trips.get(stopTime.trip_id);
      if (currentTrip && flushedTrips.has(currentTrip.numericId)) {
        throw new Error(
          `stop_times.txt is not grouped by trip: ${currentTrip.id} reappeared after its block ended`
        );
      }
    }
    if (!currentTrip || (!stopTime.departure_time && !stopTime.arrival_time)) continue;

    const stopId = canonicalStopIdOf(stopTime.stop_id);
    const stopKey = stopKeyById.get(stopId);
    if (stopKey === undefined) {
      counters.skippedStops += 1;
      continue;
    }

    const arrivalSeconds = parseGtfsTime(stopTime.arrival_time || stopTime.departure_time);
    const departureSeconds = parseGtfsTime(stopTime.departure_time || stopTime.arrival_time);
    stopRoutePairs.set(`${stopId}\u0000${currentTrip.routeId}`, {
      stopId,
      routeId: currentTrip.routeId,
    });
    counters.departureCount += 1;
    if (counters.departureCount % 1_000_000 === 0) {
      console.log(`Streamed ${counters.departureCount} stop-times…`);
    }
    calls.push(Number(stopTime.stop_sequence), stopKey, arrivalSeconds, departureSeconds);
  }
  flush();

  return { profiles, profileKeyByTrip, startSecondsByTrip };
}
