ALTER TABLE "transit_route_pattern_stops" ADD COLUMN "snapped_location" geometry(Point,4326);--> statement-breakpoint
ALTER TABLE "transit_route_pattern_stops" ADD COLUMN "snap_distance_m" double precision;--> statement-breakpoint
CREATE INDEX "transit_routes_route_type_idx" ON "transit_routes" USING btree ("route_type");--> statement-breakpoint
-- Backfill the projection for rows already imported. The importer keeps it fresh
-- on every subsequent run, but without this the columns would stay NULL until the
-- next GTFS import and the network map would come back empty.
UPDATE "transit_route_pattern_stops" AS prs
SET "snapped_location" = ST_ClosestPoint(p."geometry", s."location"),
    "snap_distance_m"  = ST_Distance(p."geometry"::geography, s."location"::geography)
FROM "transit_route_patterns" AS p, "transit_stops" AS s
WHERE prs."pattern_id" = p."id" AND prs."stop_id" = s."id";
