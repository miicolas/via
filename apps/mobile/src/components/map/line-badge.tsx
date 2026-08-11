import type { NetworkRoute } from '@via/contract';
import { StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';

type LineBadgeProps = {
  /**
   * Never undefined: `networkState` only reports `ready` once a line resolves, so
   * the placeholder branch this used to carry is unreachable.
   */
  route: NetworkRoute;
  size: number;
};

/** The coloured pill carrying a line number, as used by the summary and the selector. */
export function LineBadge({ route, size }: LineBadgeProps) {
  return (
    <View
      style={[
        styles.badge,
        {
          minWidth: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor: route.color,
        },
      ]}
    >
      <ThemedText type="smallBold" style={{ color: route.textColor }}>
        {route.shortName}
      </ThemedText>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    paddingHorizontal: 6,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
