const DEFAULT_API_BASE_URL = 'https://usevia.up.railway.app/api/';
const DEFAULT_COUNT = 1;

type ProbeResult = {
  index: number;
  httpStatus: number;
  status: string;
  source: string;
  journeyCount: number;
  transitJourneyCount: number;
  durationMs: number;
};

const count = positiveIntegerArgument('--count') ?? DEFAULT_COUNT;
const baseUrl = new URL(stringArgument('--base-url') ?? DEFAULT_API_BASE_URL);
const requestedAt = instantArgument('--requested-at');
const clientKey = requiredClientKey(process.env.VIA_APP_CLIENT_KEYS);

const runId = `${Date.now().toString(36)}-${crypto.randomUUID().slice(0, 8)}`;
const results: ProbeResult[] = [];

for (let index = 0; index < count; index += 1) {
  results.push(await probe(index + 1));
}

for (const result of results) {
  console.log(
    [
      `probe=${result.index}`,
      `http=${result.httpStatus}`,
      `status=${result.status}`,
      `source=${result.source}`,
      `journeys=${result.journeyCount}`,
      `transit=${result.transitJourneyCount}`,
      `durationMs=${result.durationMs}`,
    ].join(' ')
  );
}

const failures = results.filter(
  (result) => result.httpStatus !== 200 || result.transitJourneyCount === 0
);
const passes = results.length - failures.length;
console.log(`VERDICT ${failures.length === 0 ? 'PASS' : 'FAIL'}: ${passes}/${results.length} réponses avec transport`);

if (failures.length > 0) process.exitCode = 1;

async function probe(index: number): Promise<ProbeResult> {
  const url = new URL('journeys', ensureTrailingSlash(baseUrl));
  const query: Record<string, string> = {
    'origin[latitude]': '48.949315',
    'origin[longitude]': '2.034841',
    'destination[kind]': 'address',
    // Address IDs only partition Via's cache. PRIM receives the coordinates,
    // so a unique suffix forces a fresh end-to-end plan without changing it.
    'destination[id]': `75102_9893_00015:diagnostic:${runId}:${index}`,
    'destination[name]': '15 Rue Vivienne',
    'destination[latitude]': '48.868267',
    'destination[longitude]': '2.33964',
    limit: '4',
  };
  if (requestedAt) query.requestedAt = requestedAt;
  for (const [key, value] of Object.entries(query)) url.searchParams.set(key, value);

  const startedAt = performance.now();
  const response = await fetch(url, {
    headers: {
      'x-via-client-key': clientKey,
      'cache-control': 'no-cache',
    },
    signal: AbortSignal.timeout(20_000),
  });
  const body = await response.json() as {
    status?: string;
    source?: string;
    journeys?: Array<{ sections?: Array<{ type?: string }> }>;
    error?: { code?: string };
  };
  const journeys = Array.isArray(body.journeys) ? body.journeys : [];
  const transitJourneyCount = journeys.filter((journey) =>
    journey.sections?.some((section) => section.type === 'transit')
  ).length;

  return {
    index,
    httpStatus: response.status,
    status: body.status ?? body.error?.code ?? 'unknown',
    source: body.source ?? 'none',
    journeyCount: journeys.length,
    transitJourneyCount,
    durationMs: Math.round(performance.now() - startedAt),
  };
}

function firstConfiguredSecret(raw: string | undefined) {
  return raw?.split(',').map((value) => value.trim()).find(Boolean);
}

function requiredClientKey(raw: string | undefined): string {
  const value = firstConfiguredSecret(raw);
  if (!value) throw new Error('VIA_APP_CLIENT_KEYS must be loaded from .env');
  return value;
}

function ensureTrailingSlash(url: URL) {
  const value = new URL(url);
  if (!value.pathname.endsWith('/')) value.pathname += '/';
  return value;
}

function stringArgument(name: string) {
  const index = Bun.argv.indexOf(name);
  if (index < 0) return undefined;
  const value = Bun.argv[index + 1];
  if (!value || value.startsWith('--')) throw new Error(`${name} expects a value`);
  return value;
}

function positiveIntegerArgument(name: string) {
  const value = stringArgument(name);
  if (value === undefined) return undefined;
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed < 1) throw new Error(`${name} expects a positive integer`);
  return parsed;
}

function instantArgument(name: string) {
  const value = stringArgument(name);
  if (value === undefined) return undefined;
  const instant = new Date(value);
  if (Number.isNaN(instant.getTime())) throw new Error(`${name} expects an ISO 8601 instant`);
  return instant.toISOString();
}
