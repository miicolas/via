import type { BuildConfig, DeployConfig } from "railway/iac";
import {
  defineRailway,
  fn,
  github,
  image,
  preserve,
  project,
  redis,
  service,
  volume,
} from "railway/iac";

export default defineRailway(() => {
  const via = github("miicolas/via");
  const Redis = redis("Redis");
  const redisVolume = volume("redis-volume", {
    alerts: { usage: { "80": {}, "95": {}, "100": {} } },
    allowOnlineResize: true,
    region: "europe-west4-drams3a",
    sizeMB: 5000,
  });
  const postgisVolume = volume("postgis-volume", {
    alerts: { usage: { "80": {}, "95": {}, "100": {} } },
    allowOnlineResize: true,
    region: "europe-west4-drams3a",
    sizeMB: 5000,
  });

  const viaApi = service("@via/api", {
    source: via,
    build: {
      buildCommand: "bun run --filter=@via/api typecheck",
      buildEnvironment: "V3",
      builder: "RAILPACK",
      watchPatterns: [
        "/apps/api/**",
        "/packages/**",
        "/package.json",
        "/bun.lock",
        "/turbo.json",
        "/patches/**",
      ],
    },
    start: "bun run --filter=@via/api start",
    healthcheck: "/api/health",
    replicas: 1,
    deploy: {
      preDeployCommand: ["bun --cwd packages/db ./node_modules/.bin/drizzle-kit migrate"],
    },
    networking: { privateNetworkEndpoint: "viaapi" },
    env: {
      API_KEY_PRISM_IDFM: preserve(),
      APNS_BUNDLE_ID: preserve(),
      APNS_KEY_ID: preserve(),
      APNS_PRIVATE_KEY: preserve(),
      APNS_TEAM_ID: preserve(),
      APPLE_APP_BUNDLE_IDENTIFIER: preserve(),
      APPLE_CLIENT_ID: preserve(),
      APPLE_KEY_ID: preserve(),
      APPLE_PRIVATE_KEY: preserve(),
      APPLE_TEAM_ID: preserve(),
      BETTER_AUTH_SECRET: preserve(),
      BETTER_AUTH_URL: preserve(),
      DATABASE_URL: preserve(),
      EXPO_PUBLIC_API_URL: preserve(),
      NATURAL_JOURNEYS_BREAKER_COOLDOWN_SECONDS: preserve(),
      NATURAL_JOURNEYS_BREAKER_FAILURES: preserve(),
      NATURAL_JOURNEYS_ENABLED: preserve(),
      NATURAL_JOURNEYS_PERSONAL_LIMIT: preserve(),
      NATURAL_JOURNEYS_PERSONAL_WINDOW_SECONDS: preserve(),
      NATURAL_JOURNEYS_ROLLOUT_PERCENT: preserve(),
      OPENAI_API_KEY: preserve(),
      OPENAI_MODEL: preserve(),
      PORT: preserve(),
      POSTGRES_PORT: preserve(),
      PRIM_DAILY_BUDGET: preserve(),
      PRIM_DISRUPTIONS_DAILY_BUDGET: preserve(),
      PRIM_DISRUPTIONS_URL: preserve(),
      PRIM_JOURNEYS_DAILY_BUDGET: preserve(),
      PRIM_JOURNEYS_PERSONAL_LIMIT: preserve(),
      PRIM_JOURNEYS_PERSONAL_WINDOW_SECONDS: preserve(),
      PRIM_JOURNEY_PLANNER_URL: preserve(),
      REDIS_PORT: preserve(),
      REDIS_URL: preserve(),
      VIA_ALLOWED_ORIGINS: preserve(),
      VIA_APP_CLIENT_KEYS: preserve(),
      VIA_SITE_CLIENT_KEYS: preserve(),
    },
  });

  const viaMarketing = service("@via/marketing", {
    source: via,
    replicas: 1,
    configFile: "/railway.marketing.json",
    build: {
      buildCommand: "bun run --filter=@via/marketing build",
      buildEnvironment: "V3",
      builder: "RAILPACK",
      watchPatterns: [
        "/apps/marketing/**",
        "/package.json",
        "/bun.lock",
        "/turbo.json",
        "/patches/**",
        "/railway.marketing.json",
      ],
    },
    start: "bun run --filter=@via/marketing start",
    healthcheck: "/",
    domains: ["metyro.app", "www.metyro.app"],
    env: {
      NEXT_PUBLIC_API_URL: preserve(),
      NEXT_PUBLIC_SITE_URL: preserve(),
      VIA_SITE_CLIENT_KEY: preserve(),
    },
  });

  // Every worker cron ships the same package behind the same typecheck and the
  // same migration step. They were three copies until their watch patterns
  // drifted and a cron quietly stopped rebuilding on a contract change, so the
  // parts that must not differ live here and only the schedule and entrypoint
  // stay at the call site.
  const workerCronBuild = {
    buildCommand: "bun run --filter=@via/worker typecheck",
    buildEnvironment: "V3",
    builder: "RAILPACK",
    watchPatterns: [
      "/apps/worker/**",
      "/packages/contract/**",
      "/packages/db/**",
      "/package.json",
      "/bun.lock",
      "/turbo.json",
      "/patches/**",
    ],
  } satisfies BuildConfig;

  const workerCronDeploy = (cronSchedule: string) =>
    ({
      cronSchedule,
      preDeployCommand: ["bun --cwd packages/db ./node_modules/.bin/drizzle-kit migrate"],
      restartPolicyType: "NEVER",
    }) satisfies DeployConfig;

  const viaToiletsCron = service("@via/toilets-cron", {
    source: via,
    replicas: 1,
    build: workerCronBuild,
    start: "bun apps/worker/src/toilets/cli.ts",
    deploy: {
      ...workerCronDeploy("17 3 * * *"),
      ipv6EgressEnabled: false,
    },
    env: {
      DATABASE_URL: preserve(),
      REDIS_URL: preserve(),
    },
  });

  const PostGIS = service("PostGIS", {
    source: image("postgis/postgis:16-master"),
    replicas: 1,
    deploy: {
      requiredMountPath: "/var/lib/postgresql/data",
    },
    networking: { privateNetworkEndpoint: "postgis" },
    tcp: [5432],
    volumeMounts: {
      "/var/lib/postgresql/data": postgisVolume,
    },
    env: {
      DATABASE_PRIVATE_URL: preserve(),
      DATABASE_URL: preserve(),
      PGDATA: preserve(),
      PGHOST: preserve(),
      PGPORT: preserve(),
      POSTGRES_DB: preserve(),
      POSTGRES_INITDB_ARGS: preserve(),
      POSTGRES_PASSWORD: preserve(),
      POSTGRES_USER: preserve(),
    },
  });

  const viaGtfsCron = fn("@via/gtfs-cron", {
    source: via,
    build: workerCronBuild,
    start: "bun apps/worker/src/prim/cli.ts",
    deploy: {
      // Runs after IDFM's 08:00, 13:00 and 17:00 publication windows.
      // Railway schedules are UTC-only.
      ...workerCronDeploy("30 18 * * *"),
      ipv6EgressEnabled: false,
    },
    env: {
      DATABASE_URL: PostGIS.env.DATABASE_URL,
      // Dataset token ("JEUX DE DONNÉES"), never the realtime PRIM API key.
      PRIM_STATIC_DATA_TOKEN: preserve(),
    },
  });

  const viaElevatorsCron = fn("@via/elevators-cron", {
    source: via,
    configFile: "/apps/worker/railway.elevators.json",
    build: workerCronBuild,
    start: "bun apps/worker/src/elevators/cli.ts",
    // 09:00, 14:00 and 18:00 Paris summer time; Railway cron is UTC-only.
    deploy: workerCronDeploy("0 7,12,16 * * *"),
    env: {
      DATABASE_URL: PostGIS.env.DATABASE_URL,
      // This is the PRIM "Données statiques" token, not the realtime API token.
      PRIM_STATIC_DATA_TOKEN: preserve(),
    },
  });

  return project("satisfied-strength", {
    resources: [
      viaApi,
      viaMarketing,
      viaToiletsCron,
      viaGtfsCron,
      viaElevatorsCron,
      PostGIS,
      Redis,
      redisVolume,
      postgisVolume,
    ],
  });
});
