import type { JourneySection, JourneyStop } from '@via/contract';

/** The stops ridden through, without the boarding and alighting ones the row already names. */
export function intermediateStops(section: JourneySection): JourneyStop[] {
  return section.stops.length > 2 ? section.stops.slice(1, -1) : [];
}
