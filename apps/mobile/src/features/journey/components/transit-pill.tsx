import { StyleSheet, Text } from 'react-native';

import type { LineBadgeRoute } from '@/components/map/line-badge';
import { GlassLineBadge } from '@/features/journey/components/glass-line-badge';
import { JourneyLegPill } from '@/features/journey/components/leg-pill';

type JourneyTransitPillProps = {
  /** Duration, already worded for the density the strip chose. Absent: badge only. */
  label?: string;
  route: LineBadgeRoute;
};

/**
 * One line of the journey on its own colours. The badge is the network's logo — its
 * shape says metro, RER or bus — drawn as glass so it sits in a pill that already
 * wears the line's colour instead of stamping a second solid on top of it.
 */
export function JourneyTransitPill({ label, route }: JourneyTransitPillProps) {
  return (
    <JourneyLegPill background={route.color}>
      <GlassLineBadge route={route} size={24} />
      {label ? (
        <Text numberOfLines={1} style={[styles.label, { color: route.textColor }]}>
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
