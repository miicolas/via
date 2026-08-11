import {
  db,
  stops,
  transitRoutePatterns,
  transitRoutePatternStops,
  transitRoutes,
  transitStops,
} from '@via/db';
import { and, asc, eq, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';

const app = new Hono();

app.use(logger());
app.use('/api/*', cors());

/**
 * Routes are declared as a single chain so `AppType` carries the full route
 * table — that's what makes the typed client (`hc<AppType>`) work in the app.
 */
const routes = app
  .get('/api/health', async (c) => {
    const [{ ok }] = await db.execute<{ ok: number }>(sql`select 1 as ok`);
    return c.json({ status: 'ok' as const, db: ok === 1, at: new Date().toISOString() });
  })

  /**
   * Stops within `radius` metres of a point, nearest first.
   * Casting to `geography` makes PostGIS answer in metres rather than degrees.
   */
  .get('/api/stops', async (c) => {
    const lat = Number(c.req.query('lat'));
    const lon = Number(c.req.query('lon'));
    const radius = Number(c.req.query('radius') ?? 1000);

    if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
      return c.json({ error: 'lat and lon are required numbers' }, 400);
    }

    const point = sql`ST_SetSRID(ST_MakePoint(${lon}, ${lat}), 4326)::geography`;

    const rows = await db
      .select({
        id: stops.id,
        name: stops.name,
        location: stops.location,
        distanceM: sql<number>`ST_Distance(${stops.location}::geography, ${point})`,
      })
      .from(stops)
      .where(sql`ST_DWithin(${stops.location}::geography, ${point}, ${radius})`)
      .orderBy(sql`ST_Distance(${stops.location}::geography, ${point})`)
      .limit(50);

    return c.json({ stops: rows });
  })

  .get('/api/routes/:routeId/map', async (c) => {
    const routeId = c.req.param('routeId');
    const [route] = await db
      .select()
      .from(transitRoutes)
      .where(eq(transitRoutes.id, routeId))
      .limit(1);

    if (!route) {
      return c.json({ error: 'route not found' as const }, 404);
    }

    const [pattern] = await db
      .select({
        id: transitRoutePatterns.id,
        directionId: transitRoutePatterns.directionId,
        headsign: transitRoutePatterns.headsign,
        geometry: sql<string>`ST_AsGeoJSON(${transitRoutePatterns.geometry})`,
      })
      .from(transitRoutePatterns)
      .where(
        and(
          eq(transitRoutePatterns.routeId, routeId),
          eq(transitRoutePatterns.isCanonical, true)
        )
      )
      .limit(1);

    if (!pattern) {
      return c.json({ error: 'route geometry not found' as const }, 404);
    }

    const stationRows = await db
      .select({
        id: transitStops.id,
        name: transitStops.name,
        sequence: transitRoutePatternStops.stopSequence,
        longitude: sql<number>`ST_X(ST_ClosestPoint(${transitRoutePatterns.geometry}, ${transitStops.location}))`,
        latitude: sql<number>`ST_Y(ST_ClosestPoint(${transitRoutePatterns.geometry}, ${transitStops.location}))`,
      })
      .from(transitRoutePatternStops)
      .innerJoin(
        transitRoutePatterns,
        eq(transitRoutePatternStops.patternId, transitRoutePatterns.id)
      )
      .innerJoin(transitStops, eq(transitRoutePatternStops.stopId, transitStops.id))
      .where(eq(transitRoutePatternStops.patternId, pattern.id))
      .orderBy(asc(transitRoutePatternStops.stopSequence));

    const geoJson = JSON.parse(pattern.geometry) as {
      type: 'LineString';
      coordinates: [number, number][];
    };

    return c.json({
      route: {
        id: route.id,
        shortName: route.shortName,
        longName: route.longName,
        color: `#${route.color}`,
        textColor: `#${route.textColor}`,
      },
      line: {
        id: pattern.id,
        directionId: pattern.directionId,
        headsign: pattern.headsign,
        coordinates: geoJson.coordinates.map(([longitude, latitude]) => ({
          latitude,
          longitude,
        })),
      },
      stations: stationRows.map((station) => ({
        id: station.id,
        name: station.name,
        sequence: station.sequence,
        latitude: Number(station.latitude),
        longitude: Number(station.longitude),
      })),
    });
  });

export { app };
export type AppType = typeof routes;
