import { sql, type SQL } from 'drizzle-orm';

import { transitRoutePatterns, transitRoutePatternStops, transitStops } from './schema';

/**
 * Where a station dot sits on a line.
 *
 * GTFS records a station at its street entrance — tens of metres off the
 * alignment, sometimes across the road. Drawn as recorded, the dot floats beside
 * the track instead of sitting on it. The projection is the one thing the map
 * needs that the feed does not provide.
 *
 * It only changes when an import runs, so it is computed once and stored:
 * `snapped_location` is the point on the track, `snap_distance_m` how far the
 * station had to move to reach it, in metres. That distance is not decoration —
 * it is the key the read side ranks on when a station is served by several of a
 * line's tracks, so the two halves of the rule agree by construction rather than
 * by two people writing the same SQL twice.
 *
 * An UPDATE rather than a value on INSERT because it depends on a join, which
 * neither an INSERT nor a Postgres generated column can express.
 *
 * Migration 0002 carries a copy of this statement to backfill rows that predate
 * it. That copy is frozen history, not the definition — this module is.
 */
export function projectStopsOntoPatterns(): SQL {
  return sql`
    UPDATE ${transitRoutePatternStops} AS prs
    SET snapped_location = ST_ClosestPoint(p.geometry, s.location),
        snap_distance_m  = ST_Distance(p.geometry::geography, s.location::geography)
    FROM ${transitRoutePatterns} AS p, ${transitStops} AS s
    WHERE prs.pattern_id = p.id AND prs.stop_id = s.id
  `;
}

/**
 * Of the tracks of one line that call at a station, the projection onto the one
 * the station actually sits closest to.
 *
 * Ranking on the stored metres rather than recomputing a distance keeps a single
 * notion of "closest" in the system. The two disagree more than you would guess:
 * at 48.9°N a degree of longitude is ~73 km against ~111 km for a degree of
 * latitude, so a mostly east-west offset measures short in planar degrees and
 * long in metres.
 */
export function nearestSnappedPoint(): SQL {
  return sql`(array_agg(${transitRoutePatternStops.snappedLocation} ORDER BY ${transitRoutePatternStops.snapDistanceM}))[1]`;
}
