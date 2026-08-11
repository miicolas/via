import { GlassView } from 'expo-glass-effect';
import { StyleSheet, View } from 'react-native';

import { LineBadge } from '@/components/map/line-badge';
import { ThemedText } from '@/components/themed-text';
import { Spacing } from '@/constants/theme';
import { isInterchange, type NetworkRoute, type RouteStation } from '@/lib/network-map';

const BADGE_SIZE = 32;

type RouteSummaryProps = {
  route: NetworkRoute | undefined;
  stations: RouteStation[];
};

/** Glass card recapping the selected line: badge, name and station counts. */
export function RouteSummary({ route, stations }: RouteSummaryProps) {
  const interchangeCount = stations.filter(isInterchange).length;

  return (
    <GlassView
      glassEffectStyle="clear"
      style={styles.summary}
      accessible
      accessibilityLabel={route ? `Ligne ${route.shortName} du métro` : 'Réseau du métro'}
    >
      <LineBadge route={route} size={BADGE_SIZE} />
      <View style={styles.text}>
        <ThemedText type="smallBold">
          {route ? `Ligne ${route.shortName}` : 'Métro parisien'}
        </ThemedText>
        <ThemedText type="small" themeColor="textSecondary" numberOfLines={1}>
          {route
            ? `${stations.length} stations · ${interchangeCount} correspondances`
            : 'Chargement du réseau…'}
        </ThemedText>
      </View>
    </GlassView>
  );
}

const styles = StyleSheet.create({
  summary: {
    alignSelf: 'flex-start',
    maxWidth: 330,
    minHeight: 54,
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.two,
    paddingHorizontal: 10,
    paddingVertical: Spacing.two,
    borderRadius: 18,
    borderCurve: 'continuous',
  },
  text: { flex: 1, gap: Spacing.half },
});
