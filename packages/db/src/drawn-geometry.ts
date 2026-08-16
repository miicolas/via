import { sql, type SQL } from 'drizzle-orm';

import { drawnRouteCondition } from './network-scope';
import { transitRoutePatterns, transitRoutePatternStops, transitRoutes } from './schema';

/**
 * Two tracks closer than this are the same piece of line drawn twice — the
 * outbound and return patterns of a transit line run on parallel tracks a few
 * metres apart. Loops and branches sit far beyond it and survive as their own
 * strokes.
 */
const DUPLICATE_TRACK_TOLERANCE_METERS = 25;

/**
 * One centreline per route, plus only the branches that leave it.
 *
 * The importer has already chosen one canonical pattern for each route. It is
 * the stable visual spine: drawing it untouched avoids replacing pieces of it
 * with a return track whenever the two directions drift more than the duplicate
 * tolerance. A non-canonical pattern only contributes when it reaches a station
 * neither the canonical spine nor an earlier branch reaches; an opposite
 * direction cannot make a second line. Real branches and one-way terminal loops
 * are then reduced to track outside everything already retained.
 *
 * Like `snapped_location`, the result only changes when an import runs, so it
 * is computed once here and stored — the read side serves it with a plain
 * indexed SELECT instead of seconds of windowed PostGIS per request. An UPDATE
 * rather than a value on INSERT because it depends on every sibling pattern of
 * the route, which neither an INSERT nor a generated column can express.
 *
 * `ST_CollectionExtract(..., 2)` keeps the difference's line pieces (it can
 * also leave points where tracks touch), and `ST_Multi` pins the column type,
 * so a canonical LineString and a multi-piece branch store as the same shape.
 *
 * Migration 0010 carries a copy of this statement to backfill rows that predate
 * it. That copy is frozen history, not the definition — this module is.
 */
export function computeDrawnGeometry(): SQL {
  return sql`
    WITH normalized AS (
      SELECT p.id AS pattern_id,
        CASE
          WHEN p.is_canonical THEN ST_Multi(p.geometry)
          WHEN EXISTS (
            SELECT 1 FROM ${transitRoutePatternStops} AS candidate_stops
            WHERE candidate_stops.pattern_id = p.id
              AND NOT EXISTS (
                SELECT 1 FROM ${transitRoutePatternStops} AS covered_stops
                JOIN ${transitRoutePatterns} AS covering_patterns
                  ON covered_stops.pattern_id = covering_patterns.id
                WHERE covering_patterns.route_id = p.route_id
                  AND (covering_patterns.is_canonical OR covering_patterns.id < p.id)
                  AND covered_stops.stop_id = candidate_stops.stop_id
              )
          ) THEN ST_Multi(ST_CollectionExtract(ST_LineMerge(ST_Difference(
            p.geometry,
            ST_Buffer(ST_Collect(
              COALESCE(
                ST_Union(p.geometry) FILTER (WHERE p.is_canonical)
                  OVER (PARTITION BY p.route_id),
                ST_GeomFromText('LINESTRING EMPTY', 4326)
              ),
              COALESCE(
                ST_Union(p.geometry) FILTER (WHERE NOT p.is_canonical)
                  OVER (
                    PARTITION BY p.route_id
                    ORDER BY p.id
                    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                  ),
                ST_GeomFromText('LINESTRING EMPTY', 4326)
              )
            )::geography, ${DUPLICATE_TRACK_TOLERANCE_METERS})::geometry
          )), 2))
          ELSE ST_GeomFromText('MULTILINESTRING EMPTY', 4326)
        END AS drawn_geometry
      FROM ${transitRoutePatterns} AS p
      JOIN ${transitRoutes} ON ${transitRoutes}.id = p.route_id
      WHERE ${drawnRouteCondition()}
    )
    UPDATE ${transitRoutePatterns} AS target
    SET drawn_geometry = normalized.drawn_geometry
    FROM normalized
    WHERE target.id = normalized.pattern_id
  `;
}
