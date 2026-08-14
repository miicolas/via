import type { Journey } from '@via/contract';
import { View } from 'react-native';
import Animated, { Easing, Keyframe, useReducedMotion } from 'react-native-reanimated';

import { JourneyTransferStep } from '@/features/journey/components/transfer-step';
import { JourneyTransitStep } from '@/features/journey/components/transit-step';
import { JourneyWalkStep } from '@/features/journey/components/walk-step';
import { journeyTimelineRows } from '@/features/journey/model/timeline-rows';

type JourneyTimelineProps = {
  journey: Journey;
};

/** The journey, step by step, along one rail. */
export function JourneyTimeline({ journey }: JourneyTimelineProps) {
  const reduceMotion = useReducedMotion();
  const rows = journeyTimelineRows(journey);

  return (
    <View>
      {rows.map((row, index) => {
        const key = `${journey.id}:${index}`;
        const last = index === rows.length - 1;

        let content;

        if (row.kind === 'walk') {
          content = (
            <JourneyWalkStep
              last={last}
              minutes={row.minutes}
              targetName={row.targetName}
            />
          );
        } else if (row.kind === 'transfer') {
          content = (
            <JourneyTransferStep
              last={last}
              minutes={row.minutes}
              nextRoute={row.nextRoute}
              stopName={row.stopName}
            />
          );
        } else {
          content = (
            <JourneyTransitStep
              last={last}
              minutes={row.minutes}
              section={row.section}
              stopCount={row.stopCount}
              warning={row.warning}
            />
          );
        }

        return (
          <Animated.View
            entering={timelineEntry(reduceMotion, Math.min(index, 4) * 45)}
            key={key}>
            {content}
          </Animated.View>
        );
      })}
    </View>
  );
}

/** Liquid Glass cannot be mounted below opacity zero, so rows enter with movement only. */
function timelineEntry(reduceMotion: boolean, delayMs: number) {
  if (reduceMotion) return undefined;

  return new Keyframe({
    0: { transform: [{ translateY: 8 }] },
    100: {
      transform: [{ translateY: 0 }],
      easing: Easing.bezier(0.23, 1, 0.32, 1),
    },
  })
    .duration(220)
    .delay(delayMs);
}
