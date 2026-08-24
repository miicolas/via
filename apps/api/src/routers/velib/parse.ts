import type { BikeStation } from '@via/contract';
import * as z from 'zod';

const stationIDSchema = z.union([z.string(), z.number()]).transform(String);
const binaryFlagSchema = z.union([z.boolean(), z.literal(0), z.literal(1)]).transform(Boolean);

const envelopeSchema = z.object({
  data: z.object({ stations: z.array(z.unknown()) }),
});

const informationSchema = z.object({
  station_id: stationIDSchema,
  stationCode: z.union([z.string(), z.number()]).transform(String).optional(),
  name: z.string().trim().min(1),
  lat: z.number().min(-90).max(90),
  lon: z.number().min(-180).max(180),
  capacity: z.number().int().min(0),
});

const statusSchema = z.object({
  station_id: stationIDSchema,
  num_bikes_available_types: z.array(z.record(z.string(), z.number())).default([]),
  num_docks_available: z.number().int().min(0).optional(),
  numDocksAvailable: z.number().int().min(0).optional(),
  is_installed: binaryFlagSchema,
  is_renting: binaryFlagSchema,
  is_returning: binaryFlagSchema,
  last_reported: z.number().int().min(0).optional(),
});

/**
 * Joins GBFS information and status without letting one malformed station
 * discard the other ~1,400 valid stations in the feed.
 */
export function parseVelibStations(
  informationBody: unknown,
  statusBody: unknown
): BikeStation[] | null {
  const informationEnvelope = envelopeSchema.safeParse(informationBody);
  const statusEnvelope = envelopeSchema.safeParse(statusBody);
  if (!informationEnvelope.success || !statusEnvelope.success) return null;

  const statuses = new Map<string, z.infer<typeof statusSchema>>();
  for (const candidate of statusEnvelope.data.data.stations) {
    const parsed = statusSchema.safeParse(candidate);
    if (parsed.success) statuses.set(parsed.data.station_id, parsed.data);
  }

  const stations = new Map<string, BikeStation>();
  for (const candidate of informationEnvelope.data.data.stations) {
    const parsed = informationSchema.safeParse(candidate);
    if (!parsed.success) continue;

    const information = parsed.data;
    const status = statuses.get(information.station_id);
    stations.set(information.station_id, {
      id: information.station_id,
      ...(information.stationCode ? { stationCode: information.stationCode } : {}),
      name: information.name,
      coordinate: { latitude: information.lat, longitude: information.lon },
      capacity: information.capacity,
      ...(status ? { availability: availability(status) } : {}),
    });
  }

  return [...stations.values()].sort((lhs, rhs) =>
    lhs.name.localeCompare(rhs.name, 'fr', { sensitivity: 'base' }) || lhs.id.localeCompare(rhs.id)
  );
}

function availability(status: z.infer<typeof statusSchema>) {
  const bicycleTypes = Object.assign({}, ...status.num_bikes_available_types);
  const lastReportedAt = status.last_reported
    ? new Date(status.last_reported * 1_000).toISOString()
    : undefined;

  return {
    mechanicalBikes: nonnegativeInteger(bicycleTypes.mechanical),
    electricBikes: nonnegativeInteger(bicycleTypes.ebike),
    docks: status.num_docks_available ?? status.numDocksAvailable ?? 0,
    isInstalled: status.is_installed,
    isRenting: status.is_renting,
    isReturning: status.is_returning,
    ...(lastReportedAt ? { lastReportedAt } : {}),
  };
}

function nonnegativeInteger(value: unknown) {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0 ? value : 0;
}
