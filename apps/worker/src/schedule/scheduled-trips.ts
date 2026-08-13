import type { ScheduledTrip } from './import-schedules';

type CsvRow = Record<string, string>;

export type ImportedScheduledTrip = ScheduledTrip & {
};

/**
 * Keeps every trip belonging to the imported network for the GTFS fallback.
 * Returning the parsed trip lets the network importer reuse the same validated
 * fields when it selects representative patterns.
 */
export function addScheduledTrip(
  trips: Map<string, ScheduledTrip>,
  importedRouteIds: ReadonlySet<string>,
  row: CsvRow
): ImportedScheduledTrip | undefined {
  const routeId = row.route_id;
  if (!routeId || !importedRouteIds.has(routeId)) return undefined;

  const trip = {
    numericId: trips.size + 1,
    id: required(row, 'trip_id'),
    routeId,
    directionId: Number(required(row, 'direction_id')),
    shapeId: required(row, 'shape_id'),
    headsign: required(row, 'trip_headsign'),
    serviceId: required(row, 'service_id'),
  } satisfies ImportedScheduledTrip;

  trips.set(trip.id, trip);
  return trip;
}

function required(row: CsvRow, key: string): string {
  const value = row[key];
  if (!value) {
    throw new Error(`Missing ${key} in trips.txt: ${JSON.stringify(row).slice(0, 160)}`);
  }
  return value;
}
