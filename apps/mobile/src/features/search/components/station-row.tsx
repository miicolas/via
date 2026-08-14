import type { StationSearchResult } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

import { Button } from '@/components/button';
import { LineBadge } from '@/components/map/line-badge';
import { useAppTheme } from '@/hooks/use-app-theme';
import { formatDistance } from '@/lib/format-distance';
import { compareRoutes } from '@/lib/route-order';

type StationResultRowProps = {
  onPress: () => void;
  result: StationSearchResult;
};

export function StationResultRow({ onPress, result }: StationResultRowProps) {
  const { colors } = useAppTheme();
  // The result carries its own badges, so a row renders without waiting for
  // any other payload.
  const served = [...result.routes].sort(compareRoutes);

  return (
    <Button
      contentStyle={[styles.row, { borderBottomColor: colors.line }]}
      fullWidth
      label={`Station ${result.name}`}
      onPress={onPress}
      variant="plain">
      <View style={styles.copy}>
        <Text numberOfLines={1} style={[styles.name, { color: colors.ink }]}>
          {result.name}
        </Text>
        <View style={styles.badges}>
          {served.map((route) => (
            <LineBadge key={route.id} route={route} size={20} />
          ))}
        </View>
      </View>
      {result.distanceMeters !== undefined ? (
        <Text style={[styles.distance, { color: colors.muted }]}>
          {formatDistance(result.distanceMeters)}
        </Text>
      ) : null}
    </Button>
  );
}

const styles = StyleSheet.create({
  row: {
    minHeight: 64,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  copy: { flex: 1, gap: 5, paddingVertical: 10 },
  name: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 17,
    lineHeight: 21,
  },
  badges: { flexDirection: 'row', flexWrap: 'wrap', gap: 4 },
  distance: {
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
  },
});
