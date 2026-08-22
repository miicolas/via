import * as z from "zod";

const isTest = process.env.NODE_ENV === "test";
const testOnlyApplePrivateKey = `-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgqpkXoLd3+EqE6nz1
Jphj6OCZr4c52j0/TTC7d2GG4EShRANCAAQSuz3cNXv84QDkzqfD0BAWxo/4d7YY
CQZjpwTJEWwrBcZdi52FIKJJhA4XZ1+WdkMoxeatICRWdr4Ng/BMWRCQ
-----END PRIVATE KEY-----`;

/**
 * Only the variables the API itself reads. `DATABASE_URL` is deliberately absent:
 * `packages/db` already validates and owns it, and two owners of one variable is
 * how error messages start disagreeing with each other.
 *
 * The default sits on the string rather than on the number, so it fills in before
 * the transform runs instead of leaning on coercion order.
 */
const envSchema = z.object({
  PORT: z
    .string()
    .default("3000")
    .transform(Number)
    .pipe(z.number().int().min(1).max(65_535)),
  /** Better Auth signs the cookie value exposed to the native app as its Bearer token. */
  BETTER_AUTH_SECRET: isTest
    ? z.string().min(32).default("via-tests-only-secret-at-least-32-characters")
    : z.string().min(32),
  BETTER_AUTH_URL: isTest ? z.url().default("http://localhost:3000") : z.url(),
  APPLE_CLIENT_ID: z.string().min(1).default("dev.via.app"),
  APPLE_APP_BUNDLE_IDENTIFIER: z.string().min(1).default("dev.via.app"),
  APPLE_TEAM_ID: z.string().min(1).default("HZAYG4Q47N"),
  APPLE_KEY_ID: isTest
    ? z.string().min(1).default("test-key")
    : z.string().min(1),
  APPLE_PRIVATE_KEY: isTest
    ? z.string().min(1).default(testOnlyApplePrivateKey)
    : z.string().min(1),
  /** APNs provider credentials are optional so local development can use the registration API without sending pushes. */
  APNS_TEAM_ID: z
    .string()
    .min(1)
    .default(process.env.APPLE_TEAM_ID ?? "HZAYG4Q47N"),
  APNS_KEY_ID: z.string().min(1).optional(),
  APNS_PRIVATE_KEY: z.string().min(1).optional(),
  APNS_BUNDLE_ID: z
    .string()
    .min(1)
    .default(process.env.APPLE_APP_BUNDLE_IDENTIFIER ?? "dev.via.app"),
  /** The Géoplateforme (BAN) geocoder. Overridable to point tests at a fake. */
  BAN_SEARCH_URL: z.url().default("https://data.geopf.fr/geocodage/search"),
  /** Local or hosted Redis used for the PRIM cache and daily quota counter. */
  REDIS_URL: z.url().default("redis://localhost:6379"),
  /**
   * PRIM (Île-de-France Mobilités) realtime. All four are optional on purpose:
   * without them the departures route degrades to its fallback instead of the
   * whole API refusing to boot — dev without keys must keep working.
   */
  API_KEY_PRISM_IDFM: z.string().min(1).optional(),
  PRIM_STOP_MONITORING_URL: z
    .url()
    .default(
      "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring",
    ),
  /** Navitia journey planner endpoint. Keep the token server-side. */
  PRIM_JOURNEY_PLANNER_URL: z
    .url()
    .default(
      "https://prim.iledefrance-mobilites.fr/marketplace/v2/navitia/journeys",
    ),
  /** Network-wide disruptions bulk feed, refreshed through its own cache. */
  PRIM_DISRUPTIONS_URL: z
    .url()
    .default(
      "https://prim.iledefrance-mobilites.fr/marketplace/disruptions_bulk/disruptions/v2",
    ),
  /** One shared snapshot per TTL window keeps this near 720 requests/day. */
  PRIM_DISRUPTIONS_DAILY_BUDGET: z
    .string()
    .default("800")
    .transform(Number)
    .pipe(z.number().int().min(0)),
  /**
   * Daily request ceiling of the PRIM token (new tokens: 1 000/day). The
   * governor keeps a safety margin below it; raise this only after PRIM
   * grants a quota increase.
   */
  PRIM_DAILY_BUDGET: z
    .string()
    .default("1000")
    .transform(Number)
    .pipe(z.number().int().min(0)),
  /** Separate budget for journey calculations; stop monitoring has its own counter. */
  PRIM_JOURNEYS_DAILY_BUDGET: z
    .string()
    .default("1000")
    .transform(Number)
    .pipe(z.number().int().min(0)),
  /** Per-person burst protection before a journey may spend the global quota. */
  PRIM_JOURNEYS_PERSONAL_LIMIT: z
    .string()
    .default("20")
    .transform(Number)
    .pipe(z.number().int().min(1)),
  PRIM_JOURNEYS_PERSONAL_WINDOW_SECONDS: z
    .string()
    .default("900")
    .transform(Number)
    .pipe(z.number().int().min(60)),
  /**
   * OpenAI fallback for the natural-language journey agent. The key is optional
   * on purpose: without it the `/natural-journeys` route answers with the
   * recoverable double-failure instead of the whole API refusing to boot, and
   * the key never leaves this backend. See docs/adr for the fallback contract.
   */
  OPENAI_API_KEY: z.string().min(1).optional(),
  /** OpenAI presents gpt-5.6-luna as its high-volume GPT-5.6 model; override per env. */
  OPENAI_MODEL: z.string().min(1).default("gpt-5.6-luna"),
  /** Global per-submission timeout. The plan mandates no automatic retry. */
  OPENAI_TIMEOUT_MS: z
    .string()
    .default("8000")
    .transform(Number)
    .pipe(z.number().int().min(1_000).max(60_000)),
  /** Per-person fallback ceiling: 20 submissions per 15-minute window. */
  OPENAI_PERSONAL_LIMIT: z
    .string()
    .default("20")
    .transform(Number)
    .pipe(z.number().int().min(1)),
  OPENAI_PERSONAL_WINDOW_SECONDS: z
    .string()
    .default("900")
    .transform(Number)
    .pipe(z.number().int().min(60)),
  /** Circuit breaker: open after 5 consecutive OpenAI failures, for 60 seconds. */
  OPENAI_BREAKER_FAILURE_THRESHOLD: z
    .string()
    .default("5")
    .transform(Number)
    .pipe(z.number().int().min(1)),
  OPENAI_BREAKER_OPEN_SECONDS: z
    .string()
    .default("60")
    .transform(Number)
    .pipe(z.number().int().min(1)),
  /**
   * Secret keying the HMAC that derives `safety_identifier`. Optional: it falls
   * back to BETTER_AUTH_SECRET so a fresh deploy still never sends OpenAI a raw
   * user id, while a dedicated secret can rotate independently later.
   */
  OPENAI_SAFETY_SECRET: z.string().min(16).optional(),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error(`[api] invalid environment:\n${z.prettifyError(parsed.error)}`);
  throw new Error(
    "Invalid environment. Copy .env.example to .env at the repo root.",
  );
}

export const env = parsed.data;
