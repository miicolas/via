import type { LineBranch, LineDirection, LineDisruption } from '@via/contract';

import { activityOf } from './disruptions/activity';
import type { DisruptionSeverity, NormalizedDisruption } from './disruptions/parse';
import type { LineBranchStopRow, LineSchemaStopRow } from './queries';

const SEVERITY_RANK: Record<DisruptionSeverity, number> = {
  attention: 1,
  disrupted: 2,
  suspended: 3,
};

/** Branch-stop rows, already in branch-then-travel order, → branch strips. */
export function toLineBranches(rows: LineBranchStopRow[]): LineBranch[] {
  const branches: LineBranch[] = [];
  let current: LineBranch | undefined;

  for (const row of rows) {
    if (current?.id !== row.patternId) {
      current = {
        id: row.patternId,
        directionId: row.directionId,
        headsign: row.headsign,
        isCanonical: row.isCanonical,
        stops: [],
      };
      branches.push(current);
    }
    current.stops.push({ id: row.stopId, name: row.stopName });
  }
  return branches;
}

/** Schema rows, already in direction-section-position order, → directions. */
export function toLineDirections(rows: LineSchemaStopRow[]): LineDirection[] {
  const directions: LineDirection[] = [];
  let sectionKey: string | undefined;

  for (const row of rows) {
    let direction = directions.at(-1);
    if (direction?.directionId !== row.directionId) {
      direction = { directionId: row.directionId, label: row.directionLabel, sections: [] };
      directions.push(direction);
      sectionKey = undefined;
    }
    const rowKey = `${row.directionId} ${row.sectionIndex}`;
    if (sectionKey !== rowKey) {
      direction.sections.push({
        role: row.sectionRole,
        ...(row.sectionLabel === null ? {} : { label: row.sectionLabel }),
        origins: row.sectionOrigins,
        termini: row.sectionTermini,
        stops: [],
      });
      sectionKey = rowKey;
    }
    direction.sections.at(-1)!.stops.push({
      id: row.stopId,
      name: row.stopName,
      isInterchange: row.isInterchange,
    });
  }
  return directions;
}

/**
 * The line's disruptions worth showing: active ones first (worst severity
 * leading), then upcoming ones by start time. Impacted sections are narrowed
 * to this line, so the schema only greys out its own segments.
 */
export function toLineDisruptions(
  routeId: string,
  disruptions: NormalizedDisruption[],
  nowSeconds: number
): LineDisruption[] {
  const active: Array<{ disruption: NormalizedDisruption }> = [];
  const upcoming: Array<{ disruption: NormalizedDisruption; beginsAt: number }> = [];

  for (const disruption of disruptions) {
    if (!disruption.routeIds.includes(routeId)) continue;

    const activity = activityOf(disruption.periods, nowSeconds);
    if (activity.kind === 'active') active.push({ disruption });
    else if (activity.kind === 'upcoming') upcoming.push({ disruption, beginsAt: activity.beginsAt });
  }

  active.sort(
    (left, right) =>
      SEVERITY_RANK[right.disruption.severity] - SEVERITY_RANK[left.disruption.severity]
  );
  upcoming.sort((left, right) => left.beginsAt - right.beginsAt);

  return [
    ...active.map(({ disruption }) => toLineDisruption(routeId, disruption, 'active')),
    ...upcoming.map(({ disruption }) => toLineDisruption(routeId, disruption, 'upcoming')),
  ];
}

function toLineDisruption(
  routeId: string,
  disruption: NormalizedDisruption,
  activity: 'active' | 'upcoming'
): LineDisruption {
  return {
    id: disruption.id,
    severity: disruption.severity,
    activity,
    ...(disruption.cause === undefined ? {} : { cause: disruption.cause }),
    ...(disruption.title === undefined ? {} : { title: disruption.title }),
    ...(disruption.message === undefined ? {} : { message: disruption.message }),
    periods: disruption.periods.map((period) => ({
      beginsAt: new Date(period.beginsAt * 1_000).toISOString(),
      endsAt: new Date(period.endsAt * 1_000).toISOString(),
    })),
    impactedSections: disruption.impactedSections
      .filter((section) => section.routeId === routeId)
      .map(({ fromStopId, fromName, toStopId, toName }) => ({
        fromStopId,
        fromName,
        toStopId,
        toName,
      })),
    ...(disruption.updatedAt === undefined
      ? {}
      : { updatedAt: new Date(disruption.updatedAt * 1_000).toISOString() }),
  };
}
