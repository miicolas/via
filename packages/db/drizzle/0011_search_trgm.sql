-- The index migration 0004 promised: with the full IDFM feed (14 853 stops) the
-- accent-insensitive LIKE scan is the slow half of /search/query, so give it a
-- trigram index. `unaccent()` is only STABLE (the dictionary is a run-time
-- lookup), and an expression index requires IMMUTABLE, so wrap it with the
-- dictionary pinned to a constant. Safe here: `public.unaccent` ships with the
-- extension and never changes meaning for this data.
CREATE EXTENSION IF NOT EXISTS pg_trgm;--> statement-breakpoint
CREATE OR REPLACE FUNCTION immutable_unaccent(text)
RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT
RETURN public.unaccent('public.unaccent'::regdictionary, $1);--> statement-breakpoint
-- The exact expression `selectMatchingStations` puts in its WHERE clause — the
-- planner only uses an expression index on a verbatim match.
CREATE INDEX "transit_stops_name_unaccent_trgm_idx"
  ON "transit_stops"
  USING gin (immutable_unaccent(lower("name")) gin_trgm_ops);
