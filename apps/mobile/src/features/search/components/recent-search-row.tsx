import type { RecentSearchSnapshot } from '@/features/search/model/recent-searches';
import { SymbolIcon } from '@/components/symbol-icon';
import { Button } from '@/components/button';
import { LineBadge } from '@/components/map/line-badge';
import { useAppTheme } from '@/hooks/use-app-theme';
import { compareRoutes } from '@/lib/route-order';
import { StyleSheet, Text, View } from 'react-native';

type RecentSearchRowProps = {
  onPress: () => void;
  result: RecentSearchSnapshot;
};

export function RecentSearchRow({ onPress, result }: RecentSearchRowProps) {
  const { colors } = useAppTheme();

  return (
    <Button
      accessibilityHint="Ouvre cette destination"
      contentStyle={[styles.row, { borderBottomColor: colors.line }]}
      fullWidth
      label={`${result.name}, recherche récente`}
      onPress={onPress}
      style={styles.host}
      variant="plain">
      <SymbolIcon color={colors.muted} name="clock" size={24} weight="regular" />
      <View style={styles.copy}>
        <Text numberOfLines={1} selectable style={[styles.name, { color: colors.ink }]}>
          {result.name}
        </Text>
        {result.kind === 'station' ? (
          <View style={styles.badges}>
            {[...result.routes].sort(compareRoutes).map((route) => (
              <LineBadge key={route.id} route={route} size={26} />
            ))}
          </View>
        ) : (
          <Text numberOfLines={1} selectable style={[styles.context, { color: colors.muted }]}>
            {result.context}
          </Text>
        )}
      </View>
    </Button>
  );
}

const styles = StyleSheet.create({
  // Keep the SwiftUI/Yoga bridge from collapsing the custom button to its
  // default 44-point control height while the row content is measuring.
  host: { minHeight: 76 },
  row: {
    minHeight: 76,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 20,
    borderBottomWidth: StyleSheet.hairlineWidth,
    backgroundColor: 'transparent',
  },
  copy: { flex: 1, gap: 5 },
  name: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 18,
    lineHeight: 22,
  },
  context: {
    fontFamily: 'Inter_400Regular',
    fontSize: 16,
  },
  badges: { flexDirection: 'row', flexWrap: 'wrap', gap: 5 },
});
