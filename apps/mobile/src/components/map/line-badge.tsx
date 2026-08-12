import type { NetworkRoute } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

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
          width: Math.max(size, route.shortName.length * 9 + 12),
          height: size,
          borderRadius: size / 2,
          backgroundColor: route.color,
        },
      ]}
    >
      <Text
        style={[
          styles.label,
          { color: route.textColor, fontSize: size * 0.5, lineHeight: size * 0.58 },
        ]}>
        {route.shortName}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    paddingHorizontal: 6,
    alignItems: 'center',
    justifyContent: 'center',
  },
  label: { fontFamily: 'Archivo_800ExtraBold', letterSpacing: -0.5 },
});
