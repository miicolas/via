export type MeetupPlanAvailability =
  | 'ready'
  | 'fallback-at-destination'
  | 'unavailable'
  | 'stale';

export type MeetupReplanReason =
  | 'participant-accepted'
  | 'organizer-update'
  | 'origin-change'
  | 'member-change'
  | 'missed-connection'
  | 'scheduled-refresh';

export type MeetupFreshnessCategory = 'live' | 'delayed' | 'stale' | 'offline';

/**
 * The complete Meetup telemetry vocabulary. It deliberately has no generic
 * metadata bag, identifiers, names, location fields, tokens or ciphertext.
 */
export type MeetupMetric =
  | { event: 'creation' }
  | { event: 'acceptance' }
  | { event: 'plan-availability'; category: MeetupPlanAvailability }
  | { event: 'replan'; reason: MeetupReplanReason; category: MeetupPlanAvailability }
  | { event: 'join-succeeded' }
  | { event: 'freshness'; category: MeetupFreshnessCategory };

/** Picks every logged field explicitly, even if an untyped caller supplies extras. */
export function meetupMetricPayload(metric: MeetupMetric): Record<string, string> {
  switch (metric.event) {
  case 'creation':
  case 'acceptance':
  case 'join-succeeded':
    return { event: metric.event };
  case 'plan-availability':
  case 'freshness':
    return { event: metric.event, category: metric.category };
  case 'replan':
    return { event: metric.event, reason: metric.reason, category: metric.category };
  }
}

export function recordMeetupMetric(metric: MeetupMetric): void {
  console.info('[meetups] aggregate', meetupMetricPayload(metric));
}
