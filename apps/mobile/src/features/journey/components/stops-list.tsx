import type { JourneyStop } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';
import Animated, { FadeInDown, useReducedMotion } from 'react-native-reanimated';

import { useAppTheme } from '@/hooks/use-app-theme';

type JourneyStopsListProps = {
  stops: JourneyStop[];
};

/** The stops a ride passes through, revealed under the transit step on demand. */
export function JourneyStopsList({ stops }: JourneyStopsListProps) {
  const { colors } = useAppTheme();
  const reduceMotion = useReducedMotion();

  return (
    <Animated.View
      entering={reduceMotion ? undefined : FadeInDown.duration(180)}
      style={[styles.list, { borderLeftColor: colors.line }]}>
      {stops.map((stop) => (
        <Text key={stop.id} numberOfLines={1} style={[styles.stop, { color: colors.muted }]}>
          {stop.name}
        </Text>
      ))}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  list: {
    gap: 7,
    marginTop: 2,
    paddingLeft: 12,
    borderLeftWidth: 2,
  },
  stop: { fontFamily: 'Inter_400Regular', fontSize: 13, lineHeight: 16 },
});
