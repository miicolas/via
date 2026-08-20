import { Readable, type Writable } from 'node:stream';
import { pipeline } from 'node:stream/promises';

import type { PositionalCsv } from '../csv';
import { parseGtfsTime } from './gtfs-time';

import type { ScheduledTrip } from './import-schedules';

export type TimeProfileCall = {
  stopKey: number;
  arrivalOffset: number;
  departureOffset: number;
};

export type TimeProfileAssignment = {
  profileKey: number;
  startSeconds: number;
};

/**
 * Owns the timetable encoding produced by one GTFS import. Callers work with
 * semantic assignments and calls; the flat-vector stride, zero sentinel,
 * dense profile ids, and COPY text representation stay inside this module.
 */
export class TimeProfileBuild {
  readonly stopRoutePairs: ReadonlyMap<string, { stopId: string; routeId: string }>;
  readonly stats: Readonly<{ departureCount: number; skippedStops: number }>;

  readonly #profiles: readonly Int32Array[];
  readonly #profileKeyByTrip: Int32Array;
  readonly #startSecondsByTrip: Int32Array;

  constructor(
    profiles: readonly Int32Array[],
    profileKeyByTrip: Int32Array,
    startSecondsByTrip: Int32Array,
    stopRoutePairs: ReadonlyMap<string, { stopId: string; routeId: string }>,
    stats: Readonly<{ departureCount: number; skippedStops: number }>
  ) {
    this.#profiles = profiles;
    this.#profileKeyByTrip = profileKeyByTrip;
    this.#startSecondsByTrip = startSecondsByTrip;
    this.stopRoutePairs = stopRoutePairs;
    this.stats = stats;
  }

  get profileCount(): number {
    return this.#profiles.length;
  }

  get callCount(): number {
    return this.#profiles.reduce((total, vector) => total + vector.length / 3, 0);
  }

  assignmentForTrip(tripNumericId: number): TimeProfileAssignment | undefined {
    const profileKey = this.#profileKeyByTrip[tripNumericId];
    if (profileKey === 0) return undefined;
    return { profileKey, startSeconds: this.#startSecondsByTrip[tripNumericId] };
  }

  callsForTrip(tripNumericId: number): TimeProfileCall[] {
    const assignment = this.assignmentForTrip(tripNumericId);
    if (!assignment) return [];
    const vector = this.#profiles[assignment.profileKey - 1];
    const calls: TimeProfileCall[] = [];
    for (let index = 0; index < vector.length; index += 3) {
      calls.push({
        stopKey: vector[index],
        arrivalOffset: vector[index + 1],
        departureOffset: vector[index + 2],
      });
    }
    return calls;
  }

  async writeProfileStopsTo(destination: Writable): Promise<void> {
    await pipeline(Readable.from(this.#copyRows()), destination);
  }

  *#copyRows(): Generator<string> {
    for (let index = 0; index < this.#profiles.length; index += 1) {
      const vector = this.#profiles[index];
      const profileKey = index + 1;
      for (let call = 0; call < vector.length; call += 3) {
        yield `${profileKey}\t${call / 3}\t${vector[call]}\t${vector[call + 1]}\t${vector[call + 2]}\n`;
      }
    }
  }
}

/** The only fields of stop_times.txt this build reads. */
export const STOP_TIME_COLUMNS = [
  'trip_id',
  'stop_sequence',
  'stop_id',
  'arrival_time',
  'departure_time',
] as const;

export type StopTimeColumn = (typeof STOP_TIME_COLUMNS)[number];

type BuildTimeProfilesOptions = {
  stopTimes: PositionalCsv<StopTimeColumn>;
  trips: ReadonlyMap<string, ScheduledTrip>;
  canonicalStopIdOf: (stopId: string) => string;
  stopKeyById: ReadonlyMap<string, number>;
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
}: BuildTimeProfilesOptions): Promise<TimeProfileBuild> {
  const profiles: Int32Array[] = [];
  const profileIdByVector = new Map<string, number>();
  const profileKeyByTrip = new Int32Array(trips.size + 1);
  const startSecondsByTrip = new Int32Array(trips.size + 1);
  /** One byte per trip rather than a Set: trip ids are already dense 1..N. */
  const flushedTrips = new Uint8Array(trips.size + 1);
  const stopRoutePairs = new Map<string, { stopId: string; routeId: string }>();
  const stats = { departureCount: 0, skippedStops: 0 };

  let currentTripId: string | undefined;
  let currentTrip: ScheduledTrip | undefined;
  /** Flat (stopSequence, stopKey, arrivalSeconds, departureSeconds) tuples. */
  let calls: number[] = [];

  const flush = () => {
    if (!currentTrip) return;
    flushedTrips[currentTrip.numericId] = 1;
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

  // Resolved once, outside the 14.5M-iteration loop.
  const { column, rows } = stopTimes;
  const tripIdAt = column.trip_id;
  const stopSequenceAt = column.stop_sequence;
  const stopIdAt = column.stop_id;
  const arrivalAt = column.arrival_time;
  const departureAt = column.departure_time;

  for await (const stopTime of rows) {
    const tripId = stopTime[tripIdAt];
    if (tripId !== currentTripId) {
      flush();
      calls = [];
      currentTripId = tripId;
      currentTrip = trips.get(tripId);
      if (currentTrip && flushedTrips[currentTrip.numericId] === 1) {
        throw new Error(
          `stop_times.txt is not grouped by trip: ${currentTrip.id} reappeared after its block ended`
        );
      }
    }
    const arrival = stopTime[arrivalAt];
    const departure = stopTime[departureAt];
    if (!currentTrip || (!departure && !arrival)) continue;

    const stopId = canonicalStopIdOf(stopTime[stopIdAt]);
    const stopKey = stopKeyById.get(stopId);
    if (stopKey === undefined) {
      stats.skippedStops += 1;
      continue;
    }

    const arrivalSeconds = parseGtfsTime(arrival || departure);
    const departureSeconds = parseGtfsTime(departure || arrival);
    stopRoutePairs.set(`${stopId}\u0000${currentTrip.routeId}`, {
      stopId,
      routeId: currentTrip.routeId,
    });
    stats.departureCount += 1;
    calls.push(Number(stopTime[stopSequenceAt]), stopKey, arrivalSeconds, departureSeconds);
  }
  flush();

  return new TimeProfileBuild(
    profiles,
    profileKeyByTrip,
    startSecondsByTrip,
    stopRoutePairs,
    stats
  );
}
