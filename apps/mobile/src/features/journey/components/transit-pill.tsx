import { StyleSheet, Text } from 'react-native';

import { LineBadge, type LineBadgeRoute } from '@/components/map/line-badge';
import { JourneyLegPill } from '@/features/journey/components/leg-pill';
import { useAppTheme } from '@/hooks/use-app-theme';
import { withAlpha } from '@/lib/with-alpha';

type JourneyTransitPillProps = {
  /** Duration, already worded for the density the strip chose. Absent: badge only. */
  label?: string;
  route: LineBadgeRoute;
};

/** Keeps the official line colour solid while its shared badge stays readable above it. */
export function JourneyTransitPill({ label, route }: JourneyTransitPillProps) {
  const { colors } = useAppTheme();

  return (
    <JourneyLegPill background={withAlpha(route.color, 0.2)}>
      <LineBadge route={route} size={24} />
      {label ? (
        <Text numberOfLines={1} style={[styles.label, { color: colors.ink }]}>
          {label}
        </Text>
      ) : null}
    </JourneyLegPill>
  );
}

const styles = StyleSheet.create({
  label: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 14,
    fontVariant: ['tabular-nums'],
  },
});
