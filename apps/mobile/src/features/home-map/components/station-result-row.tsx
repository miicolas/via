import type { NetworkRoute, StationSearchResult } from '@via/contract';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { LineBadge } from '@/components/map/line-badge';
import { formatDistance } from '@/features/home-map/model/format-distance';
import { HomeMapTheme } from '@/features/home-map/styles/theme';

type StationResultRowProps = {
  onPress: () => void;
  result: StationSearchResult;
  /** The whole network's lines; the row keeps the ones serving this station. */
  routes: NetworkRoute[];
};

export function StationResultRow({ onPress, result, routes }: StationResultRowProps) {
  const served = routes.filter((route) => result.routeIds.includes(route.id));

  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
      <View style={styles.copy}>
        <Text numberOfLines={1} style={styles.name}>
          {result.name}
        </Text>
        <View style={styles.badges}>
          {served.map((route) => (
            <LineBadge key={route.id} route={route} size={20} />
          ))}
        </View>
      </View>
      {result.distanceMeters !== undefined ? (
        <Text style={styles.distance}>{formatDistance(result.distanceMeters)}</Text>
      ) : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    minHeight: 64,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#161A181F',
  },
  copy: { flex: 1, gap: 5, paddingVertical: 10 },
  name: {
    color: HomeMapTheme.ink,
    fontFamily: 'Inter_600SemiBold',
    fontSize: 17,
    lineHeight: 21,
  },
  badges: { flexDirection: 'row', flexWrap: 'wrap', gap: 4 },
  distance: {
    color: HomeMapTheme.muted,
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
  },
  pressed: { opacity: 0.5 },
});
