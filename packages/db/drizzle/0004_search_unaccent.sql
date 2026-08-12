-- Station search normalizes accents on both the column and the query, so that
-- "repu" matches "République". `unaccent` is a trusted extension since PG13:
-- no superuser needed. No index yet — the metro feed is ~300 stops, a scan is
-- instant. When the full IDFM feed lands, add pg_trgm + a GIN expression index
-- (which needs an IMMUTABLE wrapper around unaccent()).
CREATE EXTENSION IF NOT EXISTS unaccent;
