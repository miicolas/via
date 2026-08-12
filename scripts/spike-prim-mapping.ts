/**
 * Spike jetable : valide le mapping entre nos ids GTFS et les refs STIF que
 * PRIM attend, avec de vrais appels authentifiés.
 *
 *   bun --env-file=.env scripts/spike-prim-mapping.ts
 *
 * Hypothèses à confirmer (doc « OpenData_TR.pdf », dataset périmètre IDFM) :
 *   - MonitoringRef zone d'arrêt : `STIF:StopArea:SP:{n}:` où `n` est notre
 *     `transit_stops.id` sans le préfixe `IDFM:`
 *   - LineRef : `STIF:Line::{code}:` où `code` est `transit_routes.id` sans
 *     le préfixe `IDFM:` (ex. C01371)
 *
 * Sortie : pour chaque candidat, le statut HTTP et le nombre de visites ; la
 * première réponse non vide est sauvée comme fixture pour `prim/parse.test.ts`.
 */

const apiKey = process.env.API_KEY_PRISM_IDFM;
if (!apiKey) {
  console.error('API_KEY_PRISM_IDFM manquante dans .env — ajoute la clé PRIM puis relance.');
  process.exit(1);
}

const STOP_MONITORING_URL = 'https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring';
const ESTIMATED_TIMETABLE_URL =
  'https://prim.iledefrance-mobilites.fr/marketplace/estimated-timetable';

/** Échantillon relevé en base le 2026-08-12 (`transit_stops`). */
const STATIONS = [
  { id: 'IDFM:415852', name: 'Hôtel de Ville' },
  { id: 'IDFM:71264', name: 'Châtelet' },
  { id: 'IDFM:71634', name: 'Château de Vincennes' },
];

/** Ligne 1 et 11 (`transit_routes`). */
const ROUTES = [
  { id: 'IDFM:C01371', name: 'Métro 1' },
  { id: 'IDFM:C01381', name: 'Métro 11' },
];

const FIXTURE_PATH = new URL(
  '../apps/api/src/routers/departures/__fixtures__/stop-monitoring-sample.json',
  import.meta.url
);

function bareId(prefixed: string): string {
  return prefixed.replace(/^IDFM:/, '');
}

async function call(url: string, params: Record<string, string>) {
  const target = new URL(url);
  for (const [key, value] of Object.entries(params)) target.searchParams.set(key, value);
  const startedAt = Date.now();
  const response = await fetch(target, { headers: { apikey: apiKey! } });
  const elapsedMs = Date.now() - startedAt;
  const body: unknown = await response.json().catch(() => null);
  return { status: response.status, elapsedMs, body };
}

function countVisits(body: unknown): number | null {
  const deliveries = (body as any)?.Siri?.ServiceDelivery?.StopMonitoringDelivery;
  if (!Array.isArray(deliveries)) return null;
  return deliveries.flatMap((delivery: any) => delivery?.MonitoredStopVisit ?? []).length;
}

let fixtureSaved = false;

for (const station of STATIONS) {
  const n = bareId(station.id);
  const candidates = [`STIF:StopArea:SP:${n}:`, `STIF:StopPoint:Q:${n}:`];

  for (const ref of candidates) {
    const { status, elapsedMs, body } = await call(STOP_MONITORING_URL, { MonitoringRef: ref });
    const visits = countVisits(body);
    console.log(
      `${station.name.padEnd(22)} ${ref.padEnd(32)} → HTTP ${status}, visites: ${visits ?? 'n/a'} (${elapsedMs} ms)`
    );

    if (!fixtureSaved && status === 200 && visits && visits > 0) {
      await Bun.write(FIXTURE_PATH, JSON.stringify(body, null, 2));
      fixtureSaved = true;
      console.log(`  ↳ fixture sauvée : ${FIXTURE_PATH.pathname}`);
    }
  }
}

for (const route of ROUTES) {
  const ref = `STIF:Line::${bareId(route.id)}:`;
  const { status, elapsedMs, body } = await call(ESTIMATED_TIMETABLE_URL, { LineRef: ref });
  const frames = (body as any)?.Siri?.ServiceDelivery?.EstimatedTimetableDelivery;
  const journeys = Array.isArray(frames)
    ? frames
        .flatMap((frame: any) => frame?.EstimatedJourneyVersionFrame ?? [])
        .flatMap((frame: any) => frame?.EstimatedVehicleJourney ?? []).length
    : null;
  console.log(
    `${route.name.padEnd(22)} ${ref.padEnd(32)} → HTTP ${status}, journeys: ${journeys ?? 'n/a'} (${elapsedMs} ms)`
  );
}

console.log(
  '\nBudget consommé par ce spike : ~8 requêtes (6 stop-monitoring + 2 estimated-timetable).'
);
