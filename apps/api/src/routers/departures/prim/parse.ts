import { routeIdOfLineRef } from './refs';
import {
  normalizePrimDepartureStatus,
  type PrimDepartureStatus,
} from '../status';

/**
 * A departure PRIM announced, reduced to what the mapper needs. `routeId` is
 * already back in our GTFS vocabulary. Epoch seconds keep the Redis snapshot
 * compact; the API turns them into ISO strings only at the wire boundary.
 */
export type NormalizedVisit = {
  routeId: string;
  destination: string;
  scheduledAt?: number;
  expectedAt?: number;
  providerStatus?: PrimDepartureStatus;
  providerJourneyRef?: string;
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
      const scheduledAt = parseTimestampSeconds(
        scalar(call?.AimedDepartureTime) ?? scalar(call?.AimedArrivalTime)
      );
      const expectedAt = parseTimestampSeconds(
        scalar(call?.ExpectedDepartureTime) ?? scalar(call?.ExpectedArrivalTime)
      );
      const providerStatus = normalizePrimDepartureStatus(
        scalar(call?.DepartureStatus) ?? scalar(call?.ArrivalStatus)
      );
      const providerJourneyRef =
        scalar(journey.FramedVehicleJourneyRef?.DatedVehicleJourneyRef) ?? undefined;

      if (!routeId || !destination) continue;
      if (
        scheduledAt === undefined &&
        expectedAt === undefined &&
        providerStatus !== 'cancelled' &&
        providerStatus !== 'missed'
      ) {
        continue;
      }

      visits.push({
        routeId,
        destination,
        ...(scheduledAt === undefined ? {} : { scheduledAt }),
        ...(expectedAt === undefined ? {} : { expectedAt }),
        ...(providerStatus === undefined ? {} : { providerStatus }),
        ...(providerJourneyRef === undefined ? {} : { providerJourneyRef }),
      });
    }
  }
  return visits;
}

function parseTimestampSeconds(value: string | null): number | undefined {
  if (!value) return undefined;
  const milliseconds = Date.parse(value);
  return Number.isFinite(milliseconds) ? Math.floor(milliseconds / 1_000) : undefined;
}

function asArray(value: unknown): unknown[] {
  if (value === null || value === undefined) return [];
  return Array.isArray(value) ? value : [value];
}

/** Unwraps PRIM's `{ value }` envelopes, arrays thereof, or a bare string. */
function scalar(field: unknown): string | null {
  const candidate = Array.isArray(field) ? field[0] : field;
  if (typeof candidate === 'string') return candidate;
  const value = (candidate as { value?: unknown } | undefined)?.value;
  return typeof value === 'string' ? value : null;
}
