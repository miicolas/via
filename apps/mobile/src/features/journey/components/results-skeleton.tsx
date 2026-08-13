import { StyleSheet, View } from 'react-native';

import { GlassCard } from '@/components/glass-card';
import { PulseBlock } from '@/components/pulse-block';
import { PulseGroup } from '@/components/pulse-group';
import { DURATION_COLUMN_WIDTH } from '@/features/journey/components/duration-row';
import { LEG_PILL_HEIGHT } from '@/features/journey/components/leg-pill';
import { useAppTheme } from '@/hooks/use-app-theme';
import { SHEET_GUTTER } from '@/styles/metrics';

const PLACEHOLDER_ROWS = [3, 2, 1];

/**
 * The shape of the answer, held while it is computed: the sheet keeps the layout it
 * is about to fill instead of flashing an empty state on the way there.
 */
export function JourneyResultsSkeleton() {
  const { colors } = useAppTheme();

  return (
    <PulseGroup style={styles.skeleton}>
      <View
        accessibilityLabel="Calcul de l’itinéraire en cours"
        accessibilityRole="progressbar"
        style={styles.skeleton}>
        <View style={styles.cardSlot}>
          <GlassCard>
            <View style={styles.summary}>
              <View style={styles.strip}>
                <PulseBlock height={LEG_PILL_HEIGHT} style={styles.walk} />
                <PulseBlock height={LEG_PILL_HEIGHT} style={styles.transit} />
                <PulseBlock height={LEG_PILL_HEIGHT} style={styles.walk} />
              </View>
              <PulseBlock height={34} radius={10} style={styles.hero} />
            </View>
            <PulseBlock height={18} radius={6} style={styles.title} />
            <View style={[styles.footer, { borderTopColor: colors.hairline }]}>
              <PulseBlock height={14} radius={5} style={styles.departure} />
              <PulseBlock height={40} radius={999} style={styles.action} />
            </View>
          </GlassCard>
        </View>

        {PLACEHOLDER_ROWS.map((weight) => (
          <View key={weight} style={[styles.row, { borderBottomColor: colors.hairline }]}>
            <View style={styles.strip}>
              <PulseBlock height={LEG_PILL_HEIGHT} style={styles.walk} />
              <PulseBlock height={LEG_PILL_HEIGHT} style={{ flexBasis: 0, flexGrow: weight }} />
            </View>
            <PulseBlock height={18} radius={6} style={styles.total} />
          </View>
        ))}
      </View>
    </PulseGroup>
  );
}

const styles = StyleSheet.create({
  skeleton: { gap: 14 },
  cardSlot: { paddingHorizontal: SHEET_GUTTER },
  summary: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  strip: { minWidth: 0, flex: 1, flexDirection: 'row', alignItems: 'center', gap: 4 },
  walk: { width: 46, flexShrink: 0 },
  transit: { flexBasis: 0, flexGrow: 6 },
  hero: { width: DURATION_COLUMN_WIDTH, flexShrink: 0 },
  title: { width: '62%' },
  footer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
    paddingTop: 14,
    borderTopWidth: StyleSheet.hairlineWidth,
  },
  departure: { width: 132 },
  action: { width: 104, flexShrink: 0 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    paddingVertical: 13,
    paddingHorizontal: SHEET_GUTTER,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  total: { width: DURATION_COLUMN_WIDTH, flexShrink: 0 },
});
