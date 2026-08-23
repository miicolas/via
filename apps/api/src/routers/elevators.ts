import type { SourceSnapshotStatus, StationElevatorSnapshot } from '@via/contract';
import { db } from '@via/db';
import { stationElevators } from '@via/db/schema';
import { asc, eq, inArray, max } from 'drizzle-orm';

const MAX_SNAPSHOT_AGE_MS = 36 * 60 * 60 * 1_000;

export async function readElevatorSourceStatus(): Promise<SourceSnapshotStatus> {
  const [row] = await db
    .select({
      importedAt: max(stationElevators.importedAt),
      sourceUpdatedAt: max(stationElevators.stateUpdatedAt),
    })
    .from(stationElevators);
  return elevatorSourceStatusFromTimestamps(row?.importedAt, row?.sourceUpdatedAt);
}

/** A dynamic equipment snapshot is not presented as current forever if its cron stops. */
export function elevatorSourceStatusFromTimestamps(
  importedAtValue: Date | string | null | undefined,
  sourceUpdatedAtValue: Date | string | null | undefined,
  now = new Date()
): SourceSnapshotStatus {
  const importedAt = timestampISOString(importedAtValue);
  const sourceUpdatedAt = timestampISOString(sourceUpdatedAtValue);
  const freshnessDate = sourceUpdatedAt ?? importedAt;
  const age = freshnessDate ? now.getTime() - Date.parse(freshnessDate) : Number.POSITIVE_INFINITY;
  return {
    status: age <= MAX_SNAPSHOT_AGE_MS ? 'ok' : 'unavailable',
    sourceUpdatedAt,
    importedAt,
  };
}

export async function elevatorSnapshotForStation(
  stationId: string
): Promise<StationElevatorSnapshot> {
  const [source, rows] = await Promise.all([
    readElevatorSourceStatus(),
    db
      .select({
        id: stationElevators.id,
        status: stationElevators.status,
        reason: stationElevators.reason,
        situation: stationElevators.situation,
        direction: stationElevators.direction,
        updatedAt: stationElevators.stateUpdatedAt,
      })
      .from(stationElevators)
      .where(eq(stationElevators.stopId, stationId))
      .orderBy(asc(stationElevators.id)),
  ]);

  return {
    ...source,
    items: rows.map((row) => ({
      id: row.id,
      status: row.status,
      ...(row.reason ? { reason: row.reason } : {}),
      ...(row.situation ? { situation: row.situation } : {}),
      ...(row.direction ? { direction: row.direction } : {}),
      ...(row.updatedAt ? { updatedAt: row.updatedAt.toISOString() } : {}),
    })),
  };
}

export async function elevatorStatusesForStationIDs(ids: Iterable<string>) {
  const values = [...new Set(ids)];
  if (values.length === 0) return new Map<string, ('available' | 'notavailable' | 'unknown')[]>();
  const rows = await db
    .select({ stopId: stationElevators.stopId, status: stationElevators.status })
    .from(stationElevators)
    .where(inArray(stationElevators.stopId, values));

  const statuses = new Map<string, ('available' | 'notavailable' | 'unknown')[]>();
  for (const row of rows) {
    const station = statuses.get(row.stopId) ?? [];
    station.push(row.status);
    statuses.set(row.stopId, station);
  }
  return statuses;
}

function timestampISOString(value: Date | string | null | undefined) {
  if (value === null || value === undefined) return undefined;
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}
