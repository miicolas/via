import type {
  BikeStation,
  SharedMobilityItem,
  SharedMobilityMode,
  SharedMobilityProvider,
  SharedMobilityRestriction,
} from '@via/contract';
import * as z from 'zod';

import { parseVelibStations } from '../velib/parse';

const feedEnvelopeSchema = z.object({
  last_updated: z.number().int().min(0).optional(),
  lastUpdatedOther: z.number().int().min(0).optional(),
  ttl: z.number().int().min(0).default(0),
  data: z.record(z.string(), z.unknown()),
});

const manifestSchema = z.object({
  data: z.record(
    z.string(),
    z.object({ feeds: z.array(z.object({ name: z.string(), url: z.url() })) })
  ),
});

const vehicleTypeSchema = z.object({
  vehicle_type_id: z.union([z.string(), z.number()]).transform(String),
  form_factor: z.string().optional(),
  name: z.string().trim().min(1).optional(),
});

const freeVehicleSchema = z.object({
  bike_id: z.union([z.string(), z.number()]).transform(String),
  lat: z.number().finite().min(-90).max(90),
  lon: z.number().finite().min(-180).max(180),
  is_reserved: z.boolean().optional(),
  is_disabled: z.boolean().optional(),
  vehicle_type_id: z.union([z.string(), z.number()]).transform(String).optional(),
  vehicle_type: z.string().trim().min(1).optional(),
  current_range_meters: z.number().finite().int().min(0).optional(),
  current_fuel_percent: z.number().finite().min(0).optional(),
  last_reported: z.number().int().min(0).optional(),
  rental_uris: z.record(z.string(), z.string().min(1)).optional(),
});

const geofencePositionSchema = z.tuple([
  z.number().finite(),
  z.number().finite(),
]);

const geofencePolygonSchema = z.array(z.array(geofencePositionSchema).min(3));

const geofenceGeometrySchema = z.union([
  z.object({
    type: z.literal('Polygon'),
    coordinates: geofencePolygonSchema,
  }),
  z.object({
    type: z.literal('MultiPolygon'),
    coordinates: z.array(geofencePolygonSchema),
  }),
]);

const geofenceRuleSchema = z.object({
  ride_allowed: z.boolean().optional(),
  vehicle_type_id: z
    .union([z.string(), z.array(z.string())])
    .transform((value) => (typeof value === 'string' ? [value] : value))
    .optional(),
});

const geofenceFeatureSchema = z.object({
  properties: z.object({ rules: z.array(geofenceRuleSchema) }),
  geometry: geofenceGeometrySchema,
});

const geofenceCollectionSchema = z.object({
  geofencing_zones: z.object({
    type: z.literal('FeatureCollection'),
    features: z.array(z.unknown()),
  }),
});

/**
 * How long a response may be reused, and since when it has been true. Every
 * layer that merges feeds — a Dott system with its geofences, the systems with
 * each other — narrows this same window, so the rule that decides whether a
 * stale scooter can be served is written once, in `combineMeta`.
 */
export type ReuseWindow = {
  sourceUpdatedAt?: string;
  expiresAt?: string;
  /** False when one source response explicitly forbids reuse (for example ttl=0). */
  cacheable: boolean;
};

export type ParsedMobilityFeed = ReuseWindow & {
  items: SharedMobilityItem[];
};

type FeedMeta = ReuseWindow & {
  data: Record<string, unknown>;
};

type VehicleType = {
  mode: SharedMobilityMode | null;
  name?: string;
};

const OFFICIAL_OPERATOR_URL: Record<SharedMobilityProvider, string> = {
  dott: 'https://ridedott.com/',
  lime: 'https://li.me/',
  velib: 'https://www.velib-metropole.fr/',
  yego: 'https://www.rideyego.com/',
};

export const IDF_DOTT_SYSTEMS = ['paris', 'versailles-grand-parc', 'siemu'] as const;

export type ManifestFeed = { name: string; url: URL };

/** Selects the French manifest language when present, then English. */
export function parseManifestFeeds(body: unknown): ManifestFeed[] | null {
  const parsed = manifestSchema.safeParse(body);
  if (!parsed.success) return null;

  const languages = Object.keys(parsed.data.data);
  const language = languages.includes('fr')
    ? 'fr'
    : languages.includes('en')
      ? 'en'
      : languages[0];
  if (!language) return null;

  return parsed.data.data[language].feeds.map((feed) => ({
    name: feed.name,
    url: new URL(feed.url),
  }));
}

export function findManifestFeed(
  feeds: ManifestFeed[],
  name: string,
  system?: string
): ManifestFeed | undefined {
  return feeds.find((feed) => {
    if (feed.name !== name) return false;
    if (!system) return true;
    return feed.url.pathname.split('/').includes(system);
  });
}

/**
 * Parses a Dott/TIER free-bike feed. The system is part of the id namespace so
 * two Île-de-France systems can never overwrite one another in a tile.
 */
export function parseDottVehicles(
  freeBody: unknown,
  vehicleTypesBody: unknown,
  system: string,
  now: Date = new Date(),
  geofencingBody: unknown = null
): ParsedMobilityFeed | null {
  const geofences = parseDottGeofences(geofencingBody, now);
  const parsed = parseVehicles(
    freeBody,
    vehicleTypesBody,
    {
      provider: 'dott',
      idPrefix: `dott:${system}:`,
      operatorUrl: OFFICIAL_OPERATOR_URL.dott,
      modeForVehicle: (vehicle, type) => modeFromType(type, vehicle.vehicle_type_id),
      ...(geofences
        ? {
            restrictionForVehicle: (vehicle: z.infer<typeof freeVehicleSchema>) =>
              restrictionForVehicle(
                geofences,
                vehicle.vehicle_type_id,
                vehicle.lat,
                vehicle.lon
              ),
          }
        : {}),
    },
    now
  );
  if (!parsed || !geofences) return parsed;

  return { ...parsed, ...annotatedMeta(parsed, geofences) };
}

/** Lime Paris is exposed as a bicycle feed for this product surface. */
export function parseLimeVehicles(
  freeBody: unknown,
  vehicleTypesBody: unknown = null,
  now: Date = new Date()
): ParsedMobilityFeed | null {
  return parseVehicles(
    freeBody,
    vehicleTypesBody,
    {
      provider: 'lime',
      idPrefix: 'lime:',
      operatorUrl: OFFICIAL_OPERATOR_URL.lime,
      modeForVehicle: () => 'bicycle',
    },
    now
  );
}

/** YEGO's current GBFS feed is normalized to the product's scooter layer. */
export function parseYegoVehicles(
  freeBody: unknown,
  vehicleTypesBody: unknown = null,
  now: Date = new Date()
): ParsedMobilityFeed | null {
  return parseVehicles(
    freeBody,
    vehicleTypesBody,
    {
      provider: 'yego',
      idPrefix: 'yego:',
      operatorUrl: OFFICIAL_OPERATOR_URL.yego,
      modeForVehicle: () => 'scooter',
    },
    now
  );
}

/** Converts the existing strict Vélib' join into the generic station item. */
export function parseVelibSharedMobility(
  informationBody: unknown,
  statusBody: unknown,
  now: Date = new Date()
): ParsedMobilityFeed | null {
  const information = parseFreshFeed(informationBody, now);
  const status = parseFreshFeed(statusBody, now);
  if (!information || !status) return null;

  const stations = parseVelibStations(informationBody, statusBody);
  if (!stations) return null;

  return {
    items: stations.map(toVelibItem),
    ...combineMeta([information, status]),
  };
}

function parseVehicles(
  freeBody: unknown,
  vehicleTypesBody: unknown,
  options: {
    provider: Exclude<SharedMobilityProvider, 'velib'>;
    idPrefix: string;
    operatorUrl: string;
    modeForVehicle: (vehicle: z.infer<typeof freeVehicleSchema>, type?: VehicleType) =>
      | SharedMobilityMode
      | null;
    restrictionForVehicle?: (vehicle: z.infer<typeof freeVehicleSchema>, type?: VehicleType) =>
      | SharedMobilityRestriction
      | undefined;
  },
  now: Date
): ParsedMobilityFeed | null {
  const feed = parseFreshFeed(freeBody, now);
  if (!feed) return null;

  const bikes = z.array(z.unknown()).safeParse(feed.data.bikes);
  if (!bikes.success) return null;
  const types = parseVehicleTypes(vehicleTypesBody);

  const items: SharedMobilityItem[] = [];
  for (const candidate of bikes.data) {
    const vehicle = freeVehicleSchema.safeParse(candidate);
    if (!vehicle.success) continue;
    // Missing flags do not prove that a vehicle is rentable, so fail closed.
    if (vehicle.data.is_reserved !== false || vehicle.data.is_disabled !== false) continue;

    const type = vehicle.data.vehicle_type_id
      ? types.get(vehicle.data.vehicle_type_id)
      : undefined;
    const mode = options.modeForVehicle(vehicle.data, type);
    if (!mode) continue;
    const restriction = options.restrictionForVehicle?.(vehicle.data, type);

    const battery = batteryPercent(vehicle.data.current_fuel_percent);
    // The iOS app owns the primary deep link. If the feed has no iOS URI, the
    // normalized item falls back to the known official operator site instead of
    // silently choosing a platform-specific web link.
    const rentalUrl = vehicle.data.rental_uris?.ios;

    const item: SharedMobilityItem = {
      kind: 'vehicle',
      id: `${options.idPrefix}${vehicle.data.bike_id}`,
      provider: options.provider,
      mode,
      availability: 'available',
      coordinate: { latitude: vehicle.data.lat, longitude: vehicle.data.lon },
      ...(type?.name ?? vehicle.data.vehicle_type
        ? { vehicleType: type?.name ?? vehicle.data.vehicle_type }
        : {}),
      ...(battery !== undefined ? { batteryPercent: battery } : {}),
      ...(vehicle.data.current_range_meters !== undefined
        ? { rangeMeters: vehicle.data.current_range_meters }
        : {}),
      ...(vehicle.data.last_reported !== undefined
        ? { lastReportedAt: dateFromSeconds(vehicle.data.last_reported) }
        : {}),
      ...(restriction ? { restriction } : {}),
      ...(rentalUrl ? { rentalUrl } : {}),
      operatorUrl: options.operatorUrl,
    };
    items.push(item);
  }

  return { items, ...combineMeta([feed]) };
}

type GeofenceFeature = z.infer<typeof geofenceFeatureSchema>;
type GeofencePosition = z.infer<typeof geofencePositionSchema>;
type GeofencePolygon = z.infer<typeof geofencePolygonSchema>;
/**
 * A zone that forbids riding, with the box that encloses it.
 *
 * Every vehicle in the feed is tested against every zone, so the walk of a
 * multi-polygon's rings — thousands of vertices — has to be the last resort and
 * not the first thing tried. The box is computed once per parse and rejects
 * almost every pair for the cost of four comparisons. Zones whose rules never
 * forbid anything are dropped here rather than re-examined per vehicle.
 */
type GeofenceZone = {
  feature: GeofenceFeature;
  minLatitude: number;
  maxLatitude: number;
  minLongitude: number;
  maxLongitude: number;
};

type ParsedGeofences = ReuseWindow & {
  zones: GeofenceZone[];
};

function parseDottGeofences(body: unknown, now: Date): ParsedGeofences | null {
  const feed = parseFreshFeed(body, now);
  if (!feed) return null;

  const collection = geofenceCollectionSchema.safeParse(feed.data);
  if (!collection.success) return null;

  return {
    zones: collection.data.geofencing_zones.features.flatMap((candidate) => {
      const feature = geofenceFeatureSchema.safeParse(candidate);
      if (!feature.success) return [];
      if (!feature.data.properties.rules.some((rule) => rule.ride_allowed === false)) {
        return [];
      }
      return [{ feature: feature.data, ...boundingBox(feature.data.geometry) }];
    }),
    ...combineMeta([feed]),
  };
}

function boundingBox(geometry: GeofenceFeature['geometry']) {
  const polygons =
    geometry.type === 'Polygon' ? [geometry.coordinates] : geometry.coordinates;
  let minLatitude = Infinity;
  let maxLatitude = -Infinity;
  let minLongitude = Infinity;
  let maxLongitude = -Infinity;
  for (const polygon of polygons) {
    for (const ring of polygon) {
      for (const [longitude, latitude] of ring) {
        if (latitude < minLatitude) minLatitude = latitude;
        if (latitude > maxLatitude) maxLatitude = latitude;
        if (longitude < minLongitude) minLongitude = longitude;
        if (longitude > maxLongitude) maxLongitude = longitude;
      }
    }
  }
  return { minLatitude, maxLatitude, minLongitude, maxLongitude };
}

/**
 * The zones say what is forbidden, not how to say it: the client owns the
 * sentence and the operator's name in it. A second operator publishing
 * geofences therefore needs no second literal here.
 */
function restrictionForVehicle(
  geofences: ParsedGeofences,
  vehicleTypeID: string | undefined,
  latitude: number,
  longitude: number
): SharedMobilityRestriction | undefined {
  const isRestricted = geofences.zones.some((zone) => {
    if (
      latitude < zone.minLatitude ||
      latitude > zone.maxLatitude ||
      longitude < zone.minLongitude ||
      longitude > zone.maxLongitude
    ) {
      return false;
    }
    const matchingRule = zone.feature.properties.rules.some((rule) => {
      if (rule.ride_allowed !== false) return false;
      return !rule.vehicle_type_id || rule.vehicle_type_id.includes(vehicleTypeID ?? '');
    });
    return matchingRule && pointInGeometry(zone.feature.geometry, latitude, longitude);
  });

  return isRestricted ? 'no-ride' : undefined;
}

function pointInGeometry(
  geometry: GeofenceFeature['geometry'],
  latitude: number,
  longitude: number
): boolean {
  if (geometry.type === 'Polygon') {
    return pointInPolygon(geometry.coordinates, latitude, longitude);
  }
  return geometry.coordinates.some((polygon) => pointInPolygon(polygon, latitude, longitude));
}

function pointInPolygon(
  polygon: GeofencePolygon,
  latitude: number,
  longitude: number
): boolean {
  const [outerRing, ...holes] = polygon;
  if (!outerRing || !pointInRing(outerRing, latitude, longitude)) return false;
  return !holes.some((ring) => pointInRing(ring, latitude, longitude));
}

/** Ray casting over GeoJSON positions, whose order is [longitude, latitude]. */
function pointInRing(
  ring: GeofencePosition[],
  latitude: number,
  longitude: number
): boolean {
  let inside = false;
  for (let index = 0, previous = ring.length - 1; index < ring.length; previous = index++) {
    const [currentLongitude, currentLatitude] = ring[index];
    const [previousLongitude, previousLatitude] = ring[previous];
    const crossesLatitude =
      (currentLatitude > latitude) !== (previousLatitude > latitude);
    if (
      crossesLatitude &&
      longitude <
        ((previousLongitude - currentLongitude) * (latitude - currentLatitude)) /
          (previousLatitude - currentLatitude) +
          currentLongitude
    ) {
      inside = !inside;
    }
  }
  return inside;
}

function parseFreshFeed(body: unknown, now: Date): FeedMeta | null {
  const parsed = feedEnvelopeSchema.safeParse(body);
  if (!parsed.success) return null;

  const lastUpdated = parsed.data.last_updated ?? parsed.data.lastUpdatedOther;
  const sourceUpdatedAt = lastUpdated === undefined ? undefined : dateFromSeconds(lastUpdated);
  const expiresAt =
    lastUpdated !== undefined && parsed.data.ttl > 0
      ? dateFromSeconds(lastUpdated + parsed.data.ttl)
      : undefined;

  // ttl=0 means the source declines to promise a reuse window; the response
  // is usable now but the cache layer must not retain it.
  if (expiresAt && new Date(expiresAt).getTime() <= now.getTime()) return null;

  return {
    data: parsed.data.data,
    ...(sourceUpdatedAt ? { sourceUpdatedAt } : {}),
    ...(expiresAt ? { expiresAt } : {}),
    cacheable: expiresAt !== undefined,
  };
}

function parseVehicleTypes(body: unknown): Map<string, VehicleType> {
  if (!body) return new Map();
  const parsed = feedEnvelopeSchema.safeParse(body);
  if (!parsed.success) return new Map();
  const rows = z.array(z.unknown()).safeParse(parsed.data.data.vehicle_types);
  if (!rows.success) return new Map();

  const types = new Map<string, VehicleType>();
  for (const row of rows.data) {
    const type = vehicleTypeSchema.safeParse(row);
    if (!type.success) continue;
    types.set(type.data.vehicle_type_id, {
      mode: modeFromFormFactor(type.data.form_factor),
      ...(type.data.name ? { name: type.data.name } : {}),
    });
  }
  return types;
}

function modeFromType(type: VehicleType | undefined, vehicleTypeID?: string): SharedMobilityMode | null {
  return type?.mode ?? modeFromFormFactor(vehicleTypeID);
}

function modeFromFormFactor(value?: string): SharedMobilityMode | null {
  const normalized = value?.toLowerCase() ?? '';
  if (normalized.includes('bicycle') || normalized.includes('bike')) return 'bicycle';
  if (normalized.includes('scooter') || normalized.includes('moped')) return 'scooter';
  return null;
}

function batteryPercent(value: number | undefined): number | undefined {
  if (value === undefined) return undefined;
  const percent = value <= 1 ? value * 100 : value;
  return percent >= 0 && percent <= 100 ? Math.round(percent) : undefined;
}

function dateFromSeconds(seconds: number): string {
  return new Date(seconds * 1_000).toISOString();
}

/**
 * The reuse window of `base`, narrowed by a feed that only annotates it.
 *
 * Dott publishes `geofencing_zones` with `ttl=0`. That is the operator
 * declining to promise a window, not zones that expire instantly: a no-ride
 * area is a regulatory fact that changes on the scale of months, while the
 * vehicles it annotates move by the minute. Letting the annotation revoke the
 * vehicles' window made every request refetch the manifest and three feeds per
 * Île-de-France system — ten upstream calls to recover an overlay that had not
 * changed. So an annotating feed may pull the expiry in and reports its own
 * update time, but it never decides whether the fleet can be reused.
 */
export function annotatedMeta(base: ReuseWindow, annotation: ReuseWindow): ReuseWindow {
  const narrowed = combineMeta([base, annotation]);
  return { ...narrowed, cacheable: base.cacheable };
}

/**
 * The narrowest window the given feeds agree on: the earliest update, the
 * earliest expiry, and reuse allowed only if every one of them allows it.
 */
export function combineMeta(feeds: readonly ReuseWindow[]): ReuseWindow {
  const sourceUpdatedAt = feeds
    .map((feed) => feed.sourceUpdatedAt)
    .filter((date): date is string => date !== undefined)
    .sort()[0];
  const expiresAt = feeds
    .map((feed) => feed.expiresAt)
    .filter((date): date is string => date !== undefined)
    .sort()[0];
  const hasNoReuseWindow = feeds.some((feed) => !feed.cacheable);

  return {
    ...(sourceUpdatedAt ? { sourceUpdatedAt } : {}),
    ...(expiresAt ? { expiresAt } : {}),
    cacheable: !hasNoReuseWindow,
  };
}

function toVelibItem(station: BikeStation): SharedMobilityItem {
  return {
    kind: 'station',
    id: `velib:${station.id}`,
    provider: 'velib',
    name: station.name,
    coordinate: station.coordinate,
    ...(station.stationCode ? { stationCode: station.stationCode } : {}),
    capacity: station.capacity,
    ...(station.availability ? { availability: station.availability } : {}),
    operatorUrl: OFFICIAL_OPERATOR_URL.velib,
  };
}

