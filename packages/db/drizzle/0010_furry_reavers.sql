ALTER TABLE "transit_route_patterns" ADD COLUMN "drawn_geometry" geometry(MultiLineString,4326);--> statement-breakpoint
-- Backfill the drawn geometry for patterns already imported — a frozen copy of
-- `computeDrawnGeometry()` (src/drawn-geometry.ts), same precedent as the
-- snapped_location backfill in 0002. The importer keeps it fresh on every
-- subsequent run, but without this the rail map would come back empty until the
-- next GTFS import. Scope condition inlined: metro, or rail lines A–E (RER).
WITH normalized AS (
  SELECT p."id" AS pattern_id,
    CASE
      WHEN p."is_canonical" THEN ST_Multi(p."geometry")
      WHEN EXISTS (
        SELECT 1 FROM "transit_route_pattern_stops" AS candidate_stops
        WHERE candidate_stops."pattern_id" = p."id"
          AND NOT EXISTS (
            SELECT 1 FROM "transit_route_pattern_stops" AS covered_stops
            JOIN "transit_route_patterns" AS covering_patterns
              ON covered_stops."pattern_id" = covering_patterns."id"
            WHERE covering_patterns."route_id" = p."route_id"
              AND (covering_patterns."is_canonical" OR covering_patterns."id" < p."id")
              AND covered_stops."stop_id" = candidate_stops."stop_id"
          )
      ) THEN ST_Multi(ST_CollectionExtract(ST_LineMerge(ST_Difference(
        p."geometry",
        ST_Buffer(ST_Collect(
          COALESCE(
            ST_Union(p."geometry") FILTER (WHERE p."is_canonical")
              OVER (PARTITION BY p."route_id"),
            ST_GeomFromText('LINESTRING EMPTY', 4326)
          ),
          COALESCE(
            ST_Union(p."geometry") FILTER (WHERE NOT p."is_canonical")
              OVER (
                PARTITION BY p."route_id"
                ORDER BY p."id"
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
              ),
            ST_GeomFromText('LINESTRING EMPTY', 4326)
          )
        )::geography, 25)::geometry
      )), 2))
      ELSE ST_GeomFromText('MULTILINESTRING EMPTY', 4326)
    END AS drawn_geometry
  FROM "transit_route_patterns" AS p
  JOIN "transit_routes" ON "transit_routes"."id" = p."route_id"
  WHERE ("transit_routes"."route_type" = 1
    OR ("transit_routes"."route_type" = 2
      AND "transit_routes"."short_name" IN ('A', 'B', 'C', 'D', 'E')))
)
UPDATE "transit_route_patterns" AS target
SET "drawn_geometry" = normalized.drawn_geometry
FROM normalized
WHERE target."id" = normalized.pattern_id;