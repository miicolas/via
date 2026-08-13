import * as z from 'zod';

/**
 * Only the variables the API itself reads. `DATABASE_URL` is deliberately absent:
 * `packages/db` already validates and owns it, and two owners of one variable is
 * how error messages start disagreeing with each other.
 *
 * The default sits on the string rather than on the number, so it fills in before
 * the transform runs instead of leaning on coercion order.
 */
const envSchema = z.object({
  PORT: z.string().default('3000').transform(Number).pipe(z.number().int().min(1).max(65_535)),
  /** The Géoplateforme (BAN) geocoder. Overridable to point tests at a fake. */
  BAN_SEARCH_URL: z.url().default('https://data.geopf.fr/geocodage/search'),
  /** Local or hosted Redis used for the PRIM cache and daily quota counter. */
  REDIS_URL: z.url().default('redis://localhost:6379'),
  /**
   * PRIM (Île-de-France Mobilités) realtime. All four are optional on purpose:
   * without them the departures route degrades to its fallback instead of the
   * whole API refusing to boot — dev without keys must keep working.
   */
  API_KEY_PRISM_IDFM: z.string().min(1).optional(),
  PRIM_STOP_MONITORING_URL: z
    .url()
    .default('https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring'),
  /** Navitia journey planner endpoint. Keep the token server-side. */
  PRIM_JOURNEY_PLANNER_URL: z
    .url()
    .default('https://prim.iledefrance-mobilites.fr/marketplace/v2/navitia/journeys'),
  /**
   * Daily request ceiling of the PRIM token (new tokens: 1 000/day). The
   * governor keeps a safety margin below it; raise this only after PRIM
   * grants a quota increase.
  */
  PRIM_DAILY_BUDGET: z.string().default('1000').transform(Number).pipe(z.number().int().min(0)),
  /** Separate budget for journey calculations; stop monitoring has its own counter. */
  PRIM_JOURNEYS_DAILY_BUDGET: z
    .string()
    .default('1000')
    .transform(Number)
    .pipe(z.number().int().min(0)),
  /** Per-person burst protection before a journey may spend the global quota. */
  PRIM_JOURNEYS_PERSONAL_LIMIT: z
    .string()
    .default('20')
    .transform(Number)
    .pipe(z.number().int().min(1)),
  PRIM_JOURNEYS_PERSONAL_WINDOW_SECONDS: z
    .string()
    .default('900')
    .transform(Number)
    .pipe(z.number().int().min(60)),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error(`[api] invalid environment:\n${z.prettifyError(parsed.error)}`);
  throw new Error('Invalid environment. Copy .env.example to .env at the repo root.');
}

export const env = parsed.data;
