import { activityOf } from './disruptions/activity';
import type { DisruptionSeverity, NormalizedDisruption } from './disruptions/parse';

const SEVERITY_RANK: Record<DisruptionSeverity, number> = {
  attention: 1,
  disrupted: 2,
  suspended: 3,
};

export type LineServiceState = {
  condition: 'normal' | DisruptionSeverity;
  /** Title of the worst active disruption, when it carries one. */
  summary?: string;
  activeCount: number;
  upcoming?: { beginsAt: number; title?: string };
};

/**
 * Folds a line's disruptions into the one state its list row renders: the
 * worst active severity wins the badge, the earliest upcoming start feeds the
 * "fermeture prévue" indicator.
 */
export function lineServiceState(
  routeId: string,
  disruptions: NormalizedDisruption[],
  nowSeconds: number
): LineServiceState {
  let worst: NormalizedDisruption | undefined;
  let activeCount = 0;
  let upcoming: { beginsAt: number; title?: string } | undefined;

  for (const disruption of disruptions) {
    if (!disruption.routeIds.includes(routeId)) continue;

    const activity = activityOf(disruption.periods, nowSeconds);
    if (activity.kind === 'active') {
      activeCount += 1;
      if (!worst || SEVERITY_RANK[disruption.severity] > SEVERITY_RANK[worst.severity]) {
        worst = disruption;
      }
    } else if (activity.kind === 'upcoming') {
      if (!upcoming || activity.beginsAt < upcoming.beginsAt) {
        upcoming = {
          beginsAt: activity.beginsAt,
          ...(disruption.title === undefined ? {} : { title: disruption.title }),
        };
      }
    }
  }

  return {
    condition: worst?.severity ?? 'normal',
    ...(worst?.title === undefined ? {} : { summary: worst.title }),
    activeCount,
    ...(upcoming === undefined ? {} : { upcoming }),
  };
}
