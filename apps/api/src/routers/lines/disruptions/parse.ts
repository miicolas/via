import { toInstant } from '../../../time/paris';

/**
 * IDFM's three-level severity, already mapped onto the line conditions the app
 * renders: `information` → attention, `perturbee` → disrupted, `bloquante` →
 * suspended. Unknown values degrade to attention rather than dropping the
 * disruption.
 */
export type DisruptionSeverity = 'attention' | 'disrupted' | 'suspended';

/** Epoch seconds keep the Redis snapshot compact, like the departures cache. */
export type DisruptionPeriod = { beginsAt: number; endsAt: number };

/** A cut segment, back in our GTFS vocabulary (`IDFM:C01371`, `IDFM:71135`). */
export type ImpactedSection = {
  routeId: string;
  fromStopId: string;
  fromName: string;
  toStopId: string;
  toName: string;
};

export type NormalizedDisruption = {
  id: string;
  severity: DisruptionSeverity;
  cause?: string;
  title?: string;
  /** Plain text: the feed's `message` arrives as raw HTML. */
  message?: string;
  routeIds: string[];
  periods: DisruptionPeriod[];
  impactedSections: ImpactedSection[];
  updatedAt?: number;
};

/**
 * PRIM disruptions bulk → normalized disruptions. Tolerant by construction:
 * fields go missing per operator and a malformed entry must drop silently
 * rather than take the whole snapshot down. A disruption that cannot be tied
 * to at least one line is unusable for the Lines tab and is dropped.
 */
export function parseDisruptionsBulk(body: unknown): NormalizedDisruption[] {
  const feed = body as { disruptions?: unknown; lines?: unknown } | null;
  const routeIdsByDisruption = indexRoutesByDisruption(asArray(feed?.lines));

  const disruptions: NormalizedDisruption[] = [];
  for (const entry of asArray(feed?.disruptions)) {
    const raw = entry as Record<string, unknown>;
    const id = asString(raw.id);
    if (!id) continue;

    const impactedSections = parseImpactedSections(raw.impactedSections);
    const routeIds = new Set(routeIdsByDisruption.get(id) ?? []);
    for (const section of impactedSections) routeIds.add(section.routeId);
    if (routeIds.size === 0) continue;

    const title = asString(raw.title);
    const message = stripHtml(asString(raw.message) ?? '');
    const updatedAt = parseCompactParisDateTime(asString(raw.lastUpdate));

    disruptions.push({
      id,
      severity: severityOf(asString(raw.severity)),
      ...(asString(raw.cause) === null ? {} : { cause: asString(raw.cause)! }),
      ...(title === null ? {} : { title }),
      ...(message === '' ? {} : { message }),
      routeIds: [...routeIds].sort(),
      periods: parsePeriods(raw.applicationPeriods),
      impactedSections,
      ...(updatedAt === undefined ? {} : { updatedAt }),
    });
  }
  return disruptions;
}

function severityOf(value: string | null): DisruptionSeverity {
  switch (value?.toLowerCase()) {
    case 'bloquante':
      return 'suspended';
    case 'perturbee':
      return 'disrupted';
    default:
      return 'attention';
  }
}

/** `lines[]` is the feed's inverse index: line → the disruptions touching it. */
function indexRoutesByDisruption(lines: unknown[]): Map<string, string[]> {
  const index = new Map<string, string[]>();
  for (const entry of lines) {
    const line = entry as Record<string, unknown>;
    const routeId = routeIdOf(asString(line.id));
    if (!routeId) continue;

    for (const object of asArray(line.impactedObjects)) {
      for (const disruptionId of asArray((object as Record<string, unknown>).disruptionIds)) {
        if (typeof disruptionId !== 'string') continue;
        const routes = index.get(disruptionId) ?? [];
        if (!routes.includes(routeId)) routes.push(routeId);
        index.set(disruptionId, routes);
      }
    }
  }
  return index;
}

function parseImpactedSections(value: unknown): ImpactedSection[] {
  const sections: ImpactedSection[] = [];
  for (const entry of asArray(value)) {
    const section = entry as {
      lineId?: unknown;
      from?: { id?: unknown; name?: unknown };
      to?: { id?: unknown; name?: unknown };
    };
    const routeId = routeIdOf(asString(section.lineId));
    const fromStopId = stopIdOf(asString(section.from?.id));
    const toStopId = stopIdOf(asString(section.to?.id));
    const fromName = asString(section.from?.name);
    const toName = asString(section.to?.name);
    if (!routeId || !fromStopId || !toStopId || !fromName || !toName) continue;

    sections.push({ routeId, fromStopId, fromName, toStopId, toName });
  }
  return sections;
}

function parsePeriods(value: unknown): DisruptionPeriod[] {
  const periods: DisruptionPeriod[] = [];
  for (const entry of asArray(value)) {
    const period = entry as { begin?: unknown; end?: unknown };
    const beginsAt = parseCompactParisDateTime(asString(period.begin));
    const endsAt = parseCompactParisDateTime(asString(period.end));
    if (beginsAt === undefined || endsAt === undefined || endsAt < beginsAt) continue;
    periods.push({ beginsAt, endsAt });
  }
  return periods.sort((left, right) => left.beginsAt - right.beginsAt);
}

/** The feed's `20260818T220000` datetimes are Paris wall-clock, DST included. */
function parseCompactParisDateTime(value: string | null): number | undefined {
  const match = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})$/.exec(value ?? '');
  if (!match) return undefined;
  const [, year, month, day, hours, minutes, seconds] = match;
  const instant = toInstant(
    `${year}-${month}-${day}`,
    Number(hours) * 3600 + Number(minutes) * 60 + Number(seconds)
  );
  const milliseconds = Date.parse(instant);
  return Number.isFinite(milliseconds) ? Math.floor(milliseconds / 1_000) : undefined;
}

/** `line:IDFM:C01371` → `IDFM:C01371`. Null when the ref is not IDFM-shaped. */
function routeIdOf(lineId: string | null): string | null {
  const match = /^(?:line:)?IDFM:(.+)$/.exec(lineId ?? '');
  return match ? `IDFM:${match[1]}` : null;
}

/** `stop_area:IDFM:71135` → `IDFM:71135`, the id our parent stations carry. */
function stopIdOf(stopId: string | null): string | null {
  const match = /^(?:stop_area:|stop_point:)?IDFM:(.+)$/.exec(stopId ?? '');
  return match ? `IDFM:${match[1]}` : null;
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function asString(value: unknown): string | null {
  return typeof value === 'string' && value !== '' ? value : null;
}

// The structural set plus the accented Latin-1 entities French IDFM copy uses.
const NAMED_ENTITIES: Record<string, string> = {
  amp: '&',
  apos: "'",
  gt: '>',
  lt: '<',
  nbsp: ' ',
  quot: '"',
  rsquo: '’',
  agrave: 'à',
  acirc: 'â',
  ccedil: 'ç',
  eacute: 'é',
  egrave: 'è',
  ecirc: 'ê',
  euml: 'ë',
  icirc: 'î',
  iuml: 'ï',
  ocirc: 'ô',
  oelig: 'œ',
  ugrave: 'ù',
  ucirc: 'û',
  Agrave: 'À',
  Ccedil: 'Ç',
  Eacute: 'É',
  Egrave: 'È',
};

/** Block-level tags become line breaks so paragraphs survive the strip. */
function stripHtml(html: string): string {
  return html
    .replace(/<\s*(?:br|\/p|\/li|\/div)\s*\/?\s*>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&#x([0-9a-f]+);/gi, (_, hex: string) => String.fromCodePoint(Number.parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, code: string) => String.fromCodePoint(Number(code)))
    .replace(
      /&([a-z]+);/gi,
      (match, name: string) => NAMED_ENTITIES[name] ?? NAMED_ENTITIES[name.toLowerCase()] ?? match
    )
    .replace(/[^\S\n]+/g, ' ')
    .replace(/\s*\n\s*/g, '\n')
    .trim();
}
