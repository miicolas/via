import type { JourneySection } from '@via/contract';

/** Keeps routed geometry intact and only falls back to section endpoints when absent. */
export function journeySectionCoordinates(section: JourneySection) {
  return section.geometry.length > 0
    ? section.geometry
    : [section.from.coordinate, section.to.coordinate];
}
