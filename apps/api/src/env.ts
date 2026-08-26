import * as z from "zod";

const isTest = process.env.NODE_ENV === "test";
const isProduction = process.env.NODE_ENV === "production";
const testOnlyApplePrivateKey = `-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgqpkXoLd3+EqE6nz1
Jphj6OCZr4c52j0/TTC7d2GG4EShRANCAAQSuz3cNXv84QDkzqfD0BAWxo/4d7YY
CQZjpwTJEWwrBcZdi52FIKJJhA4XZ1+WdkMoxeatICRWdr4Ng/BMWRCQ
-----END PRIVATE KEY-----`;

const splitList = (raw: string) =>
  raw
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);

/** A shared secret short enough to guess is not one, hence the floor. */
const secretList = () =>
  z.string().default("").transform(splitList).pipe(z.array(z.string().min(16)));

/** Origins compare as `scheme://host[:port]`, which is what a browser sends. */
const originList = () =>
  z
    .string()
    .default("")
    .transform((raw) => splitList(raw).map((value) => value.replace(/\/+$/, "")))
    .pipe(z.array(z.url()));

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
  /**
   * Who is allowed to call this API, as secrets and as origins.
   *
   * `VIA_APP_CLIENT_KEYS` is what the iOS build presents in `x-via-client-key`
   * on `/api` and `/rpc`; a list so a key can be rotated while the previous
   * build is still on devices. `VIA_SITE_CLIENT_KEYS` is the same for the
   * marketing site's server-rendered reads. `VIA_ALLOWED_ORIGINS` is that same
   * site running in a browser, where no secret can be kept and the origin is the
   * only thing it can prove.
   *
   * All three default to empty, which leaves the API as open as it was: a
   * deployment closes itself by setting them, and the boot log names every
   * surface still open. See `http/client-gate.ts`.
   */
  VIA_APP_CLIENT_KEYS: secretList(),
  VIA_SITE_CLIENT_KEYS: secretList(),
  VIA_ALLOWED_ORIGINS: originList(),
  /** The Géoplateforme (BAN) geocoder. Overridable to point tests at a fake. */
  BAN_SEARCH_URL: z.url().default("https://data.geopf.fr/geocodage/search"),
  /** Public GBFS feeds published by Vélib' Métropole and refreshed every minute. */
  VELIB_STATION_INFORMATION_URL: z
    .url()
    .default(
      "https://velib-metropole-opendata.smovengo.cloud/opendata/Velib_Metropole/station_information.json",
    ),
  VELIB_STATION_STATUS_URL: z
    .url()
    .default(
      "https://velib-metropole-opendata.smovengo.cloud/opendata/Velib_Metropole/station_status.json",
    ),
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
  /**
   * Per-person burst protection before a journey may spend the global quota.
   * One departure-choices request fans out into several planner calls, so the
   * ceiling meters IDFM calls, not user actions — keep it well above 20.
   */
  PRIM_JOURNEYS_PERSONAL_LIMIT: z
    .string()
    .default("100")
    .transform(Number)
    .pipe(z.number().int().min(1)),
  PRIM_JOURNEYS_PERSONAL_WINDOW_SECONDS: z
    .string()
    .default("900")
    .transform(Number)
    .pipe(z.number().int().min(60)),
  /**
   * OpenAI fallback for natural-language interpretation. The key is optional
   * on purpose: without it the `/natural-journeys` route answers with the
   * recoverable unavailable result instead of the whole API refusing to boot, and
   * the key never leaves this backend. See docs/adr for the fallback contract.
   */
  OPENAI_API_KEY: z.string().min(1).optional(),
  /** High-volume GPT-5.6 model, with reasoning raised for this specialist step. */
  OPENAI_MODEL: z.string().min(1).default("gpt-5.6-luna"),
  /**
   * Global per-submission timeout. Five seconds is the latency objective, not
   * a safe hard deadline: structured generation can legitimately finish just
   * after it. The iOS request gives up at 15 s, so 12 s leaves room for the
   * response to cross the network without keeping orphaned work alive.
   */
  OPENAI_TIMEOUT_MS: z
    .string()
    .default("12000")
    .transform(Number)
    .pipe(z.number().int().min(1_000).max(60_000)),
  /**
   * High reasoning is the strongest release-gated setting within the iOS
   * deadline. `max` remains configurable, but exceeds the critical-corpus gate.
   */
  OPENAI_REASONING_EFFORT: z
    .enum(["none", "low", "medium", "high", "xhigh", "max"])
    .default("high"),
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
  /** Stable remote interpretation rollout. Set to 0 for the kill switch. */
  NATURAL_JOURNEYS_REMOTE_ROLLOUT_PERCENT: z
    .string()
    // Local and test builds must exercise the fallback. Production still
    // starts closed until its release gate explicitly raises the percentage.
    .default(isProduction ? "0" : "100")
    .transform(Number)
    .pipe(z.number().int().min(0).max(100)),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error(`[api] invalid environment:\n${z.prettifyError(parsed.error)}`);
  throw new Error(
    "Invalid environment. Copy .env.example to .env at the repo root.",
  );
}

export const env = parsed.data;
