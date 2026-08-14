import { StyleSheet, View } from 'react-native';

import { GlassSurface } from '@/components/glass-surface';
import { LineBadge } from '@/components/map/line-badge';
import { ThemedText } from '@/components/themed-text';
import { Spacing } from '@/constants/theme';
import type { LineView } from '@/lib/metro-network';

const BADGE_SIZE = 32;

type RouteSummaryProps = {
  /** One value, so the counts can never describe a different line than the badge. */
  line: LineView;
};

/** Glass card recapping the selected line: badge, name and station counts. */
export function RouteSummary({ line }: RouteSummaryProps) {
  return (
    <GlassSurface
      variant="tinted"
      style={styles.summary}
      accessible
      accessibilityLabel={`Ligne ${line.route.shortName} du métro`}
    >
      <LineBadge route={line.route} size={BADGE_SIZE} />
      <View style={styles.text}>
        <ThemedText type="smallBold">Ligne {line.route.shortName}</ThemedText>
        <ThemedText type="small" themeColor="textSecondary" numberOfLines={1}>
          {line.stations.length} stations · {line.interchangeCount} correspondances
        </ThemedText>
      </View>
    </GlassSurface>
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
