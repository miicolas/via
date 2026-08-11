import {
  db,
  transitRoutePatterns,
  transitRoutePatternStops,
  transitRoutes,
  transitStops,
} from '@via/db';
import { asc, eq, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { requestId } from 'hono/request-id';

import { toCoordinates } from './geo/coordinates';
import type { AppEnv } from './http/app-env';
import { onError } from './http/error-handler';
import { notFound } from './http/not-found';

const app = new Hono<AppEnv>();

app.use(requestId());
app.use(logger());
app.use('/api/*', cors());

/**
 * Registered off the route chain on purpose: both are app-wide and belong to no
 * route's schema, so folding them into the chain would only widen `AppType`.
 */
app.onError(onError);
app.notFound(notFound);

/**
 * Routes are declared as a single chain so `AppType` carries the full route
 * table — that's what makes the typed client (`hc<AppType>`) work in the app.
 */
const routes = app
  .get('/api/health', async (c) => {
    const [{ ok }] = await db.execute<{ ok: number }>(sql`select 1 as ok`);
    return c.json({ status: 'ok' as const, db: ok === 1, at: new Date().toISOString() });
  })

  .get('/api/network/map', async (c) => {
    // Independent queries — the station projection is the slow one, so don't wait on it twice.
    const [patternRows, stationRouteRows] = await Promise.all([
      db
        .select({
          routeId: transitRoutes.id,
          shortName: transitRoutes.shortName,
          longName: transitRoutes.longName,
          color: transitRoutes.color,
          textColor: transitRoutes.textColor,
          patternId: transitRoutePatterns.id,
          geometry: sql<string>`ST_AsGeoJSON(${transitRoutePatterns.geometry})`,
        })
        .from(transitRoutePatterns)
        .innerJoin(transitRoutes, eq(transitRoutePatterns.routeId, transitRoutes.id))
        .where(eq(transitRoutes.routeType, 1))
        .orderBy(asc(transitRoutes.shortName), asc(transitRoutePatterns.id)),

      db
        .select({
          id: transitStops.id,
          name: transitStops.name,
          routeId: transitRoutes.id,
          longitude: sql<number>`ST_X(ST_ClosestPoint(ST_Collect(${transitRoutePatterns.geometry}), ${transitStops.location}))`,
          latitude: sql<number>`ST_Y(ST_ClosestPoint(ST_Collect(${transitRoutePatterns.geometry}), ${transitStops.location}))`,
        })
        .from(transitRoutePatternStops)
        .innerJoin(
          transitRoutePatterns,
          eq(transitRoutePatternStops.patternId, transitRoutePatterns.id)
        )
        .innerJoin(transitRoutes, eq(transitRoutePatterns.routeId, transitRoutes.id))
        .innerJoin(transitStops, eq(transitRoutePatternStops.stopId, transitStops.id))
        .where(eq(transitRoutes.routeType, 1))
        .groupBy(transitStops.id, transitStops.name, transitStops.location, transitRoutes.id)
        .orderBy(asc(transitStops.name), asc(transitRoutes.id)),
    ]);

    // One row per pattern, so a route's rows collapse into its segments.
    const metroRoutes = [...Map.groupBy(patternRows, (row) => row.routeId).values()].map((rows) => {
      const [route] = rows;
      return {
        id: route.routeId,
        shortName: route.shortName,
        longName: route.longName,
        color: `#${route.color}`,
        textColor: `#${route.textColor}`,
        segments: rows.map((row) => ({
          id: row.patternId,
          coordinates: toCoordinates(row.geometry),
        })),
      };
    });

    // One row per (station, route), so a station's rows are the lines it serves.
    const metroStations = [...Map.groupBy(stationRouteRows, (row) => row.id).values()].map(
      (rows) => {
        const [station] = rows;
        return {
          id: station.id,
          name: station.name,
          routeIds: rows.map((row) => row.routeId),
          positions: Object.fromEntries(
            rows.map((row) => [
              row.routeId,
              { latitude: Number(row.latitude), longitude: Number(row.longitude) },
            ])
          ),
        };
      }
    );

    c.header('Cache-Control', 'public, max-age=300, stale-while-revalidate=3600');
    return c.json({ routes: metroRoutes, stations: metroStations });
  });

export { app };
export type AppType = typeof routes;
