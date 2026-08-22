-- `selectNextTheoreticalDepartures` runs on every departure-board request, and
-- its shape is one stop → its time profiles → every trip on those profiles. The
-- trip lookup was an index scan on `transit_trips_profile_idx` followed by a
-- heap fetch for the four columns the query actually reads, and the heap was
-- most of the cost: at La Défense, 15 681 of the query's buffer hits were that
-- fetch alone.
--
-- INCLUDE turns it into an index-only scan. Drizzle 0.45's index builder has no
-- INCLUDE, so — like the trigram index in 0011 — this one is declared here and
-- deliberately absent from `schema.ts`; drizzle-kit leaves indexes it does not
-- know about alone.
--
-- `transit_trips_profile_idx` stays: 9.6 MB against this one's 47 MB, and still
-- the cheaper choice for a bare existence check on `profile_key`.
--
-- Not CONCURRENTLY, because drizzle runs each migration inside a transaction
-- and Postgres forbids the two together. The build takes ~1.6 s on the full
-- feed (641 k trips) and holds ACCESS EXCLUSIVE on `transit_trips` for that
-- long, so departure boards stall for a second or two as it deploys.
CREATE INDEX IF NOT EXISTS "transit_trips_profile_cover_idx"
  ON "transit_trips" ("profile_key")
  INCLUDE ("service_id", "start_seconds", "route_id", "headsign");
