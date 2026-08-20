import { db } from '@via/db';
import {
  networkMode,
  transitRoutePatterns,
  transitRoutes,
  transitShapes,
} from '@via/db/schema';
import { eq, inArray } from 'drizzle-orm';

import type { JourneyShapeLoader } from './shape-hydrator';

/** Loads only representative GTFS patterns for the sparse realtime lines. */
export const loadJourneyShapes: JourneyShapeLoader = async (requests) => {
  if (requests.length === 0) return [];
  const requestedLines = new Set(
    requests.map(({ mode, shortName }) => `${mode}\u0000${shortName.trim().toUpperCase()}`)
  );
  const shortNames = [...new Set(requests.map(({ shortName }) => shortName))];
  const rows = await db
    .select({
      routeType: transitRoutes.routeType,
      shortName: transitRoutes.shortName,
      coordinates: transitShapes.geometry,
    })
    .from(transitRoutePatterns)
    .innerJoin(transitRoutes, eq(transitRoutePatterns.routeId, transitRoutes.id))
    .innerJoin(transitShapes, eq(transitRoutePatterns.id, transitShapes.id))
    .where(inArray(transitRoutes.shortName, shortNames));

  return rows.flatMap((row) => {
    const mode = networkMode(row.routeType, row.shortName);
    const key = mode ? `${mode}\u0000${row.shortName.trim().toUpperCase()}` : '';
    if (!mode || !requestedLines.has(key) || !row.coordinates || row.coordinates.length < 2) {
      return [];
    }
    return [{
      mode,
      shortName: row.shortName,
      coordinates: row.coordinates.map(({ lat, lon }) => ({ latitude: lat, longitude: lon })),
    }];
  });
};
