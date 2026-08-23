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
      VIA_APP_CLIENT_KEYS: preserve(),
      VIA_SITE_CLIENT_KEYS: preserve(),
    },
  });

  const viaToiletsCron = service("@via/toilets-cron", {
    source: via,
    replicas: 1,
    build: {
      buildCommand: "bun run --filter=@via/worker typecheck",
      buildEnvironment: "V3",
      builder: "RAILPACK",
      watchPatterns: [
        "/apps/worker/**",
        "/packages/db/**",
        "/package.json",
        "/bun.lock",
        "/turbo.json",
        "/patches/**",
        "/railway.toilets.json",
      ],
    },
    start: "bun apps/worker/src/toilets/cli.ts",
    deploy: {
      cronSchedule: "17 3 * * *",
      ipv6EgressEnabled: false,
      preDeployCommand: ["bun --cwd packages/db ./node_modules/.bin/drizzle-kit migrate"],
      restartPolicyType: "NEVER",
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

  const viaElevatorsCron = fn("@via/elevators-cron", {
    source: via,
    configFile: "/apps/worker/railway.elevators.json",
    build: {
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
      ],
    },
    start: "bun apps/worker/src/elevators/cli.ts",
    deploy: {
      cronSchedule: "0 */3 * * *",
      preDeployCommand: ["bun --cwd packages/db ./node_modules/.bin/drizzle-kit migrate"],
      restartPolicyType: "NEVER",
    },
    env: {
      DATABASE_URL: PostGIS.env.DATABASE_URL,
      // This is the PRIM "Données statiques" token, not the realtime API token.
      PRIM_STATIC_DATA_TOKEN: preserve(),
    },
  });

  return project("satisfied-strength", {
    resources: [
      viaApi,
      viaToiletsCron,
      viaElevatorsCron,
      PostGIS,
      Redis,
      redisVolume,
      postgisVolume,
    ],
  });
});
