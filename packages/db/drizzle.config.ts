import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  dialect: 'postgresql',
  schema: './src/schema.ts',
  out: './drizzle',
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
  // Keeps drizzle-kit from trying to manage PostGIS' own tables
  // (spatial_ref_sys, topology, …) as if they were ours.
  extensionsFilters: ['postgis'],
  verbose: true,
  strict: true,
});
