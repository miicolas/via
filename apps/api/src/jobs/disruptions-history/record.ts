import { createHash } from 'node:crypto';

import type { NormalizedDisruption } from '../../routers/lines/disruptions/parse';

/**
 * A disruption as the history keeps it. Deliberately the parser's own shape
 * plus bookkeeping: the value of this table is that it holds what PRIM said,
 * unnarrowed, so a question nobody has asked yet can still be answered later.
 */
export type DisruptionRecord = {
  id: string;
  severity: NormalizedDisruption['severity'];
  cause: string | null;
  title: string | null;
  message: string | null;
  routeIds: string[];
  periods: NormalizedDisruption['periods'];
  impactedSections: NormalizedDisruption['impactedSections'];
  upstreamUpdatedAt: Date | null;
  beginsAt: Date | null;
  endsAt: Date | null;
  contentHash: string;
};

/**
 * What an editor would notice changing. Severity, the text, the lines, the
 * dates and the cut segments — but not `updatedAt`, which the feed bumps on
 * every republication whether or not anything moved. Hashing it would report
 * a changed disruption every single day.
 */
export function disruptionContentHash(disruption: NormalizedDisruption): string {
  const canonical = JSON.stringify([
    disruption.severity,
    disruption.cause ?? '',
    disruption.title ?? '',
    disruption.message ?? '',
    [...disruption.routeIds].sort(),
    disruption.periods.map((period) => [period.beginsAt, period.endsAt]),
    disruption.impactedSections
      .map((section) => [section.routeId, section.fromStopId, section.toStopId])
      .sort((left, right) => left.join().localeCompare(right.join())),
  ]);

  return createHash('sha256').update(canonical).digest('hex').slice(0, 32);
}

/**
 * The outer window of a disruption: earliest start, latest end. Lifted out of
 * the periods so "which closures run this autumn" is an index scan rather than
 * a scan of every JSON blob. Null when the feed sent no usable period at all.
 */
export function disruptionWindow(disruption: NormalizedDisruption): {
  beginsAt: Date | null;
  endsAt: Date | null;
} {
  if (disruption.periods.length === 0) return { beginsAt: null, endsAt: null };

  let earliest = Number.POSITIVE_INFINITY;
  let latest = Number.NEGATIVE_INFINITY;
  for (const period of disruption.periods) {
    if (period.beginsAt < earliest) earliest = period.beginsAt;
    if (period.endsAt > latest) latest = period.endsAt;
  }

  return {
    beginsAt: new Date(earliest * 1_000),
    endsAt: new Date(latest * 1_000),
  };
}

export function toDisruptionRecord(disruption: NormalizedDisruption): DisruptionRecord {
  const { beginsAt, endsAt } = disruptionWindow(disruption);

  return {
    id: disruption.id,
    severity: disruption.severity,
    cause: disruption.cause ?? null,
    title: disruption.title ?? null,
    message: disruption.message ?? null,
    routeIds: [...disruption.routeIds].sort(),
    periods: disruption.periods,
    impactedSections: disruption.impactedSections,
    upstreamUpdatedAt:
      disruption.updatedAt === undefined ? null : new Date(disruption.updatedAt * 1_000),
    beginsAt,
    endsAt,
    contentHash: disruptionContentHash(disruption),
  };
}

/** Days a disruption spans, end to end. `0` when it carries no period. */
export function disruptionSpanDays(record: DisruptionRecord): number {
  if (!record.beginsAt || !record.endsAt) return 0;
  const milliseconds = record.endsAt.getTime() - record.beginsAt.getTime();
  return Math.max(0, Math.round(milliseconds / 86_400_000));
}
