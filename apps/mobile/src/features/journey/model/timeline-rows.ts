import type { Journey, JourneySection } from '@via/contract';

import { journeyMinutes } from '@/features/journey/model/minutes';
import { visibleJourneyWarning } from '@/features/journey/model/visible-warning';

export type TimelineRow =
  | { kind: 'walk'; minutes: number; targetName?: string }
  | {
      kind: 'transit';
      minutes: number;
      section: JourneySection;
      stopCount?: number;
      warning?: string;
    }
  | {
      kind: 'transfer';
      minutes: number;
      nextRoute?: JourneySection['route'];
      stopName: string;
    };

/**
 * Sections as timeline rows: consecutive wait/transfer legs collapse into one
 * connection row, and a wait you sit through before ever boarding is dropped —
 * the transit row's departure time already carries it.
 */
export function journeyTimelineRows(journey: Journey): TimelineRow[] {
  const { sections } = journey;
  const warning = visibleJourneyWarning(journey);
  const rows: TimelineRow[] = [];
  let firstTransit = true;
  let index = 0;

  while (index < sections.length) {
    const section = sections[index]!;

    if (section.type === 'walk') {
      rows.push({
        kind: 'walk',
        minutes: journeyMinutes(section.durationSeconds),
        targetName: section.to.name || undefined,
      });
      index += 1;
      continue;
    }

    if (section.type === 'transit') {
      rows.push({
        kind: 'transit',
        minutes: journeyMinutes(section.durationSeconds),
        section,
        stopCount: section.stops.length >= 2 ? section.stops.length - 1 : undefined,
        warning: firstTransit ? warning : undefined,
      });
      firstTransit = false;
      index += 1;
      continue;
    }

    let end = index;
    let seconds = 0;
    while (end < sections.length && isConnection(sections[end]!)) {
      seconds += sections[end]!.durationSeconds;
      end += 1;
    }

    const previous = sections[index - 1];
    if (previous?.type === 'transit') {
      rows.push({
        kind: 'transfer',
        minutes: journeyMinutes(seconds),
        nextRoute: nextTransitRoute(sections, end),
        stopName: section.from.name || previous.to.name,
      });
    }
    index = end;
  }

  return rows;
}

function isConnection(section: JourneySection) {
  return section.type === 'wait' || section.type === 'transfer';
}

function nextTransitRoute(sections: JourneySection[], from: number) {
  for (let index = from; index < sections.length; index += 1) {
    const section = sections[index]!;
    if (section.type === 'transit') return section.route;
  }
  return undefined;
}
