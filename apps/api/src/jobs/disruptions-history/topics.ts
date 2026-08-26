import { disruptionSpanDays, type DisruptionRecord } from './record';

/**
 * A disruption spanning at least this many days is a works programme, not an
 * incident. Two weeks is where "the line is down this morning" stops and "there
 * is something to explain to people planning their autumn" begins.
 */
export const LONG_RUNNING_DAYS = 14;

/** Below this, a closure is an operational blip nobody searches for. */
const MINIMUM_SPAN_DAYS = 2;

export type TopicReason = 'appeared' | 'rescheduled' | 'long-running';

export type Topic = {
  id: string;
  reasons: TopicReason[];
  severity: DisruptionRecord['severity'];
  title: string | null;
  cause: string | null;
  routeIds: string[];
  beginsAt: string | null;
  endsAt: string | null;
  spanDays: number;
  /** Station pairs the feed says are cut, for the article's line strip. */
  impactedSections: DisruptionRecord['impactedSections'];
};

export type KnownDisruption = { contentHash: string };

export type TopicReport = {
  generatedAt: string;
  /** Everything the feed carried this pass, before selection. */
  seen: number;
  topics: Topic[];
};

/**
 * Which disruptions are worth a human writing about, given what we already had
 * yesterday. This is the whole of "detection": no text is produced here, and
 * nothing is published — the output is a shortlist for an editor, and the
 * shortlist is deliberately short.
 *
 * Attention-level entries never qualify. They are overwhelmingly "expect
 * crowding" notices, they churn daily, and an article about one would be the
 * exact thin content Google penalises.
 */
export function selectTopics(
  records: readonly DisruptionRecord[],
  known: ReadonlyMap<string, KnownDisruption>,
  now: Date
): Topic[] {
  const topics: Topic[] = [];

  for (const record of records) {
    if (record.severity === 'attention') continue;

    const spanDays = disruptionSpanDays(record);
    if (spanDays < MINIMUM_SPAN_DAYS) continue;
    // A closure that is already over cannot be reported as news.
    if (record.endsAt && record.endsAt.getTime() < now.getTime()) continue;

    const previous = known.get(record.id);
    const reasons: TopicReason[] = [];
    if (!previous) reasons.push('appeared');
    else if (previous.contentHash !== record.contentHash) reasons.push('rescheduled');
    if (spanDays >= LONG_RUNNING_DAYS) reasons.push('long-running');

    // Seen before, unchanged, and not long enough to be a standing subject.
    if (reasons.length === 0) continue;

    topics.push({
      id: record.id,
      reasons,
      severity: record.severity,
      title: record.title,
      cause: record.cause,
      routeIds: record.routeIds,
      beginsAt: record.beginsAt?.toISOString() ?? null,
      endsAt: record.endsAt?.toISOString() ?? null,
      spanDays,
      impactedSections: record.impactedSections,
    });
  }

  return topics.sort(byEditorialInterest);
}

/**
 * Suspended before disrupted, then longest first: the ordering an editor would
 * use to pick what to write next.
 */
function byEditorialInterest(left: Topic, right: Topic): number {
  const severityRank = { suspended: 0, disrupted: 1, attention: 2 } as const;
  const bySeverity = severityRank[left.severity] - severityRank[right.severity];
  if (bySeverity !== 0) return bySeverity;

  const bySpan = right.spanDays - left.spanDays;
  if (bySpan !== 0) return bySpan;

  return left.id.localeCompare(right.id);
}
