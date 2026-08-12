import { routeIdOfLineRef } from './refs';

/**
 * A departure PRIM announced, reduced to what the mapper needs. `routeId` is
 * already back in our GTFS vocabulary; `expectedAt` is an ISO timestamp so the
 * whole array survives a JSON round-trip through the shared cache unchanged.
 */
export type NormalizedVisit = {
  routeId: string;
  destination: string;
  expectedAt: string;
};

/**
 * SIRI Lite stop-monitoring → normalized visits. Tolerant by construction:
 * PRIM wraps most scalars in `{ value }` (sometimes inside an array), fields
 * go missing per operator, and a malformed visit must drop silently rather
 * than take the whole response down.
 */
export function parseStopMonitoring(body: unknown): NormalizedVisit[] {
  const deliveries = asArray(
    (body as any)?.Siri?.ServiceDelivery?.StopMonitoringDelivery
  );

  const visits: NormalizedVisit[] = [];
  for (const delivery of deliveries) {
    for (const visit of asArray((delivery as any)?.MonitoredStopVisit)) {
      const journey = (visit as any)?.MonitoredVehicleJourney;
      if (!journey) continue;

      const routeId = routeIdOfLineRef(scalar(journey.LineRef) ?? '');
      const destination = scalar(journey.DestinationName) ?? scalar(journey.DirectionName);
      const call = journey.MonitoredCall;
      const expectedAt =
        scalar(call?.ExpectedDepartureTime) ?? scalar(call?.ExpectedArrivalTime);

      if (!routeId || !destination || !expectedAt) continue;
      visits.push({ routeId, destination, expectedAt });
    }
  }
  return visits;
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

/** Unwraps PRIM's `{ value }` envelopes, arrays thereof, or a bare string. */
function scalar(field: unknown): string | null {
  const candidate = Array.isArray(field) ? field[0] : field;
  if (typeof candidate === 'string') return candidate;
  const value = (candidate as { value?: unknown } | undefined)?.value;
  return typeof value === 'string' ? value : null;
}
