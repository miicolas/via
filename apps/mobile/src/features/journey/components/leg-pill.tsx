import type { ReactNode } from 'react';
import { StyleSheet, View } from 'react-native';

export const LEG_PILL_HEIGHT = 38;

type JourneyLegPillProps = {
  background: string;
  children: ReactNode;
};

/** The rounded plate every leg of the strip shares; what it carries is the caller's. */
export function JourneyLegPill({ background, children }: JourneyLegPillProps) {
  return (
    <View style={[styles.pill, { backgroundColor: background }]}>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  pill: {
    height: LEG_PILL_HEIGHT,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingHorizontal: 9,
    borderRadius: 12,
    borderCurve: 'continuous',
  },
});
