import type { JourneySegment } from '@/features/journey/model/segments';

/**
 * How much the strip can spell out before its pills crowd each other off the row.
 * Full keeps the walks; past two lines they go first, because four identical walking
 * pills say less than one more line badge. Compact still words each ride's minutes;
 * minimal is badges alone.
 */
export type StripDensity = 'full' | 'compact' | 'minimal';

/**
 * Chosen from the line count rather than measured: the thresholds map to what a
 * card's width fits, and a deterministic rule keeps every row of a list in step.
 */
export function stripDensity(segments: JourneySegment[]): StripDensity {
  const lines = segments.filter((segment) => segment.kind === 'transit').length;

  if (lines <= 2) return 'full';
  if (lines === 3) return 'compact';
  return 'minimal';
}
