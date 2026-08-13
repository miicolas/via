import { StyleSheet, Text, View } from 'react-native';

import { LineBadge, type LineBadgeRoute } from '@/components/map/line-badge';
import { JourneyTimelineRow } from '@/features/journey/components/timeline-row';
import { useAppTheme } from '@/hooks/use-app-theme';

type JourneyTransferStepProps = {
  last: boolean;
  minutes: number;
  /** The line boarded after the change; absent when the ride was the journey's last. */
  nextRoute?: LineBadgeRoute;
  stopName: string;
};

/** The change of line: where you get off, what you board next, and the time it costs. */
export function JourneyTransferStep({ last, minutes, nextRoute, stopName }: JourneyTransferStepProps) {
  const { colors } = useAppTheme();

  return (
    <JourneyTimelineRow color={colors.muted} last={last} marker="ring">
      <View style={styles.row}>
        <View style={styles.copy}>
          <Text numberOfLines={1} selectable style={[styles.title, { color: colors.ink }]}>
            {stopName}
          </Text>
          <View style={styles.hint}>
            <Text style={[styles.hintText, { color: colors.muted }]}>
              {nextRoute ? 'Tu descends ici, puis la' : 'Tu descends ici'}
            </Text>
            {nextRoute ? <LineBadge route={nextRoute} size={17} /> : null}
          </View>
        </View>
        <View style={styles.timing}>
          <Text style={[styles.minutes, { color: colors.ink }]}>{minutes} min</Text>
          <Text style={[styles.eyebrow, { color: colors.muted }]}>CORRESP.</Text>
        </View>
      </View>
    </JourneyTimelineRow>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'flex-start', gap: 12 },
  copy: { minWidth: 0, flex: 1, gap: 4 },
  title: { fontFamily: 'Inter_600SemiBold', fontSize: 15, lineHeight: 19 },
  hint: { flexDirection: 'row', alignItems: 'center', gap: 5 },
  hintText: { fontFamily: 'Inter_400Regular', fontSize: 13, lineHeight: 18 },
  timing: { flexShrink: 0, alignItems: 'flex-end', gap: 1 },
  minutes: {
    fontFamily: 'Archivo_700Bold',
    fontSize: 15,
    lineHeight: 19,
    fontVariant: ['tabular-nums'],
  },
  eyebrow: { fontFamily: 'Inter_600SemiBold', fontSize: 10, lineHeight: 13, letterSpacing: 1 },
});
