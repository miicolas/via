import type { Journey, JourneySection } from '@via/contract';

export type JourneySegment = {
  key: string;
  kind: 'transit' | 'walk' | 'wait';
  minutes: number;
  route?: NonNullable<JourneySection['route']>;
};

/**
 * Every section of the journey, in order and to scale.
 *
 * Nothing is dropped: hiding the middle of a trip made four different routes render
 * as the same three chips. Consecutive sections of one kind merge so a trip does not
 * come out as a row of one-pixel slivers, and a transfer counts as walking because
 * that is what it is.
 */
export function journeySegments(journey: Journey): JourneySegment[] {
  const segments: JourneySegment[] = [];

  for (const [index, section] of journey.sections.entries()) {
    const kind = segmentKind(section);
    const minutes = section.durationSeconds / 60;
    const previous = segments.at(-1);

    if (previous && previous.kind === kind && kind !== 'transit') {
      previous.minutes += minutes;
      continue;
    }

    segments.push({
      key: `${kind}:${section.from.name}:${section.to.name}:${index}`,
      kind,
      minutes,
      route: section.route,
    });
  }

  return segments.map((segment) => ({
    ...segment,
    minutes: Math.max(1, Math.round(segment.minutes)),
  }));
}

/** A ride with no line to name is time spent, not a leg to badge — it reads as a wait. */
function segmentKind(section: JourneySection): JourneySegment['kind'] {
  if (section.type === 'transit') return section.route ? 'transit' : 'wait';
  if (section.type === 'wait') return 'wait';

  return 'walk';
}
