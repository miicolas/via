-- Runs once, on an empty data directory, after the postgis image's own
-- init scripts (mounted as a single file so it doesn't shadow them).
-- Idempotent on purpose: the postgis image already enables these on $POSTGRES_DB.
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
