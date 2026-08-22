import { and, eq, isNotNull, sql, type SQL } from 'drizzle-orm';

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
 * `draw_rank` is that "already retained" order made explicit — canonical first,
 * then by id — so both halves of the rule become a comparison on one number
 * instead of a correlated `is_canonical OR id < …` re-derived per row. A stop is
 * first reached by exactly one rank, so `first_reach` names every branch in a
 * single grouped pass, and only those few patterns pay for geometry at all.
 *
 * The corridor to subtract is a union of per-pattern buffers rather than a
 * buffer of the accumulated union: buffering distributes over union, so the two
 * agree to floating-point noise, but this one buffers each pattern once instead
 * of re-buffering the whole route for every branch. It also drops the running
 * window `ST_Union`, whose frame ends one row back and so re-ran the aggregate's
 * final union for every pattern of every route — quadratic in patterns per
 * route, and paid even by rows the `CASE` then threw away.
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
 * One route per call. Every join and every window here already stays inside a
 * single `route_id`, so scoping the statement to one route changes no result —
 * it only turns the network-wide UPDATE into a series of statements small enough
 * to carry a timeout and to name the route that fails. `drawnRouteCondition`
 * stays in the WHERE so a caller cannot draw a route the map never draws.
 *
 * Migration 0010 carries a copy of the statement this replaced, to backfill rows
 * that predate the column. That copy is frozen history, not the definition —
 * this module is.
 */
export function computeDrawnGeometry(routeId: string): SQL {
  return sql`
    WITH scoped AS (
      SELECT p.id, p.route_id, p.geometry, p.is_canonical,
        row_number() OVER (
          PARTITION BY p.route_id ORDER BY p.is_canonical DESC, p.id
        ) AS draw_rank
      FROM ${transitRoutePatterns} AS p
      JOIN ${transitRoutes} ON ${transitRoutes}.id = p.route_id
      WHERE ${and(drawnRouteCondition(), eq(transitRoutes.id, routeId))}
    ),
    first_reach AS (
      SELECT reached.route_id, min(reached.draw_rank) AS draw_rank
      FROM (
        SELECT scoped.route_id, scoped.draw_rank, pattern_stops.stop_id
        FROM ${transitRoutePatternStops} AS pattern_stops
        JOIN scoped ON scoped.id = pattern_stops.pattern_id
      ) AS reached
      GROUP BY reached.route_id, reached.stop_id
    ),
    branch AS (
      SELECT scoped.id, scoped.route_id, scoped.geometry, scoped.draw_rank
      FROM scoped
      WHERE NOT scoped.is_canonical
        AND EXISTS (
          SELECT 1 FROM first_reach
          WHERE first_reach.route_id = scoped.route_id
            AND first_reach.draw_rank = scoped.draw_rank
        )
    ),
    covered AS (
      SELECT branch.id,
        ST_Union(
          ST_Buffer(earlier.geometry::geography, ${DUPLICATE_TRACK_TOLERANCE_METERS})::geometry
        ) AS corridor
      FROM branch
      JOIN scoped AS earlier
        ON earlier.route_id = branch.route_id
       AND earlier.draw_rank < branch.draw_rank
      GROUP BY branch.id
    ),
    resolved AS (
      SELECT scoped.id AS pattern_id,
        CASE
          WHEN scoped.is_canonical THEN ST_Multi(scoped.geometry)
          WHEN branch.id IS NULL THEN ST_GeomFromText('MULTILINESTRING EMPTY', 4326)
          ELSE ST_Multi(ST_CollectionExtract(ST_LineMerge(ST_Difference(
            scoped.geometry,
            COALESCE(covered.corridor, ST_GeomFromText('MULTILINESTRING EMPTY', 4326))
          )), 2))
        END AS drawn_geometry
      FROM scoped
      LEFT JOIN branch ON branch.id = scoped.id
      LEFT JOIN covered ON covered.id = scoped.id
    )
    UPDATE ${transitRoutePatterns} AS target
    SET drawn_geometry = resolved.drawn_geometry
    FROM resolved
    WHERE target.id = resolved.pattern_id
  `;
}

/**
 * Which routes `computeDrawnGeometry` will actually update.
 *
 * It lives beside the statement it feeds because the two share one rule: a
 * route the map never draws, or one whose patterns carry no source geometry,
 * has nothing to compute. Stated twice — once to enumerate and once inside the
 * UPDATE — the pair could silently disagree, leaving a route enumerated but
 * never updated (stale `drawn_geometry`) or updated but never named.
 */
export function drawnGeometryRouteCondition() {
  return and(drawnRouteCondition(), isNotNull(transitRoutePatterns.geometry));
}
