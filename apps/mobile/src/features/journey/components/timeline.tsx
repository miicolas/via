import type { Journey } from '@via/contract';
import { View } from 'react-native';

import { JourneyTransferStep } from '@/features/journey/components/transfer-step';
import { JourneyTransitStep } from '@/features/journey/components/transit-step';
import { JourneyWalkStep } from '@/features/journey/components/walk-step';
import { journeyTimelineRows } from '@/features/journey/model/timeline-rows';

type JourneyTimelineProps = {
  journey: Journey;
};

/** The journey, step by step, along one rail. */
export function JourneyTimeline({ journey }: JourneyTimelineProps) {
  const rows = journeyTimelineRows(journey);

  return (
    <View>
      {rows.map((row, index) => {
        const key = `${journey.id}:${index}`;
        const last = index === rows.length - 1;

        if (row.kind === 'walk') {
          return (
            <JourneyWalkStep key={key} last={last} minutes={row.minutes} targetName={row.targetName} />
          );
        }
        if (row.kind === 'transfer') {
          return (
            <JourneyTransferStep
              key={key}
              last={last}
              minutes={row.minutes}
              nextRoute={row.nextRoute}
              stopName={row.stopName}
            />
          );
        }
        return (
          <JourneyTransitStep
            key={key}
            last={last}
            minutes={row.minutes}
            section={row.section}
            stopCount={row.stopCount}
            warning={row.warning}
          />
        );
      })}
    </View>
  );
}
