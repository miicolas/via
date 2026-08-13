import type { Journey } from '@via/contract';
import { StyleSheet, View } from 'react-native';

import { JourneyTransitPill } from '@/features/journey/components/transit-pill';
import { JourneyWalkPill } from '@/features/journey/components/walk-pill';
import { journeySegments, type JourneySegment } from '@/features/journey/model/segments';
import { stripDensity, type StripDensity } from '@/features/journey/model/strip-density';

type JourneyLegStripProps = {
  /** Fades a route the network reports as disrupted, without hiding it. */
  dimmed?: boolean;
  journey: Journey;
};

/**
 * The journey as a row of pills: every line rides its own colours, walks stay quiet.
 * The more lines a trip has, the less the row spells out — walks and wording go first,
 * durations next — so a three-line trip stays one readable row instead of a crowd of
 * identical walking pills drowning the lines.
 */
export function JourneyLegStrip({ dimmed = false, journey }: JourneyLegStripProps) {
  const segments = journeySegments(journey).filter((segment) => segment.kind !== 'wait');
  const density = stripDensity(segments);

  return (
    <View style={[styles.strip, dimmed && styles.dimmed]}>
      {segments.map((segment) => {
        if (segment.route) {
          return (
            <JourneyTransitPill
              key={segment.key}
              label={durationLabel(segment, density)}
              route={segment.route}
            />
          );
        }

        if (density !== 'full') return null;
        return <JourneyWalkPill key={segment.key} minutes={segment.minutes} />;
      })}
    </View>
  );
}

/** "6 min" while there is room, "6" when lines multiply, nothing past that. */
function durationLabel(segment: JourneySegment, density: StripDensity) {
  if (density === 'full') return `${segment.minutes} min`;
  if (density === 'compact') return `${segment.minutes}`;
  return undefined;
}

const styles = StyleSheet.create({
  strip: {
    minWidth: 0,
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
  },
  dimmed: { opacity: 0.4 },
});
