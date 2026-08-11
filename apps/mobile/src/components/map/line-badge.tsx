import { StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { PLACEHOLDER_ROUTE_COLOR, type NetworkRoute } from '@/lib/network-map';

type LineBadgeProps = {
  route: NetworkRoute | undefined;
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
          backgroundColor: route?.color ?? PLACEHOLDER_ROUTE_COLOR,
        },
      ]}
    >
      <ThemedText type="smallBold" style={{ color: route?.textColor ?? '#000000' }}>
        {route?.shortName ?? '—'}
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
