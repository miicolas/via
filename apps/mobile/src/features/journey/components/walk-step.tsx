import { StyleSheet, Text } from 'react-native';

import { JourneyTimelineRow } from '@/features/journey/components/timeline-row';
import { JourneyWalkingMarker } from '@/features/journey/components/walking-marker';
import { useAppTheme } from '@/hooks/use-app-theme';

type JourneyWalkStepProps = {
  last: boolean;
  minutes: number;
  /** Where the walk lands; omitted when the feed left the endpoint unnamed. */
  targetName?: string;
};

/** A walking leg of the timeline: how long, and toward which named place. */
export function JourneyWalkStep({ last, minutes, targetName }: JourneyWalkStepProps) {
  const { colors } = useAppTheme();

  return (
    <JourneyTimelineRow
      color={colors.muted}
      last={last}
      marker="dot"
      markerContent={<JourneyWalkingMarker color={colors.muted} />}>
      <Text style={[styles.title, { color: colors.ink }]}>{minutes} min à pied</Text>
      {targetName ? (
        <Text selectable style={[styles.target, { color: colors.muted }]}>
          jusqu’à <Text style={[styles.targetName, { color: colors.ink }]}>{targetName}</Text>
        </Text>
      ) : null}
    </JourneyTimelineRow>
  );
}

const styles = StyleSheet.create({
  title: { fontFamily: 'Inter_600SemiBold', fontSize: 15, lineHeight: 19 },
  target: { fontFamily: 'Inter_400Regular', fontSize: 13, lineHeight: 18 },
  targetName: { fontFamily: 'Inter_500Medium', textDecorationLine: 'underline' },
});
