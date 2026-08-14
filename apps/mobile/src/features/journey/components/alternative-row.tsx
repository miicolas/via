import type { Journey } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

import { Button } from '@/components/button';
import { JourneyDurationRow } from '@/features/journey/components/duration-row';
import { JourneyLegStrip } from '@/features/journey/components/leg-strip';
import { JourneyQualifierTag } from '@/features/journey/components/qualifier-tag';
import { journeyMinutes } from '@/features/journey/model/minutes';
import { visibleJourneyWarning } from '@/features/journey/model/visible-warning';
import { useAppTheme } from '@/hooks/use-app-theme';
import { SHEET_GUTTER } from '@/styles/metrics';

type JourneyAlternativeRowProps = {
  journey: Journey;
  onPress: () => void;
};

/** One alternative, told apart from the others by its segments and what it offers. */
export function JourneyAlternativeRow({ journey, onPress }: JourneyAlternativeRowProps) {
  const { colors } = useAppTheme();
  const duration = journeyMinutes(journey.durationSeconds);
  const disrupted = journey.status === 'disrupted';
  const warning = visibleJourneyWarning(journey);

  return (
    <Button
      contentStyle={[styles.row, { borderBottomColor: colors.hairline }]}
      fullWidth
      label={`Itinéraire alternatif de ${duration} minutes`}
      onPress={onPress}
      variant="plain">
      <View style={styles.summary}>
        <JourneyLegStrip dimmed={disrupted} journey={journey} />
        <JourneyDurationRow arrivalAt={journey.arrivalAt} minutes={duration} struck={disrupted} />
      </View>
      <View style={styles.notes}>
        <JourneyQualifierTag qualifier={journey.qualifier} />
        {warning ? (
          <Text numberOfLines={2} selectable style={[styles.warning, { color: colors.critical }]}>
            {warning}
          </Text>
        ) : null}
      </View>
    </Button>
  );
}

const styles = StyleSheet.create({
  row: {
    gap: 7,
    paddingVertical: 13,
    paddingHorizontal: SHEET_GUTTER,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  summary: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  notes: { gap: 4 },
  warning: {
    fontFamily: 'Inter_500Medium',
    fontSize: 13,
    lineHeight: 17,
  },
});
