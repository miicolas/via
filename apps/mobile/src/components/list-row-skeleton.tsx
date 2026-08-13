import { StyleSheet, View } from 'react-native';

import { PulseBlock } from '@/components/pulse-block';
import { PulseGroup } from '@/components/pulse-group';

/** Ghost rows read as narrower than real ones, so the bars vary down the list. */
const BAR_WIDTHS = ['72%', '54%', '66%', '48%', '60%'] as const;

type ListRowSkeletonProps = {
  count: number;
  /** Leading block, e.g. a line badge or a result icon. Omit for none. */
  leadingSize?: number;
  rowHeight: number;
  /** Trailing block, e.g. a duration column. Omit for none. */
  trailingWidth?: number;
};

/**
 * The shape of a list while it loads. An empty state that flashes before results
 * reads as "nothing found" for a beat, which is the one thing it never means.
 */
export function ListRowSkeleton({
  count,
  leadingSize,
  rowHeight,
  trailingWidth,
}: ListRowSkeletonProps) {
  return (
    <PulseGroup style={styles.list}>
      <View accessibilityLabel="Chargement en cours" accessibilityRole="progressbar">
        {Array.from({ length: count }, (_, index) => (
          <View key={index} style={[styles.row, { minHeight: rowHeight }]}>
            {leadingSize ? (
              <PulseBlock
                height={leadingSize}
                radius={leadingSize / 2}
                style={{ width: leadingSize, flexShrink: 0 }}
              />
            ) : null}
            <View style={styles.copy}>
              <PulseBlock
                height={14}
                radius={5}
                style={{ width: BAR_WIDTHS[index % BAR_WIDTHS.length] }}
              />
              <PulseBlock height={11} radius={4} style={styles.secondary} />
            </View>
            {trailingWidth ? (
              <PulseBlock height={16} radius={5} style={{ width: trailingWidth, flexShrink: 0 }} />
            ) : null}
          </View>
        ))}
      </View>
    </PulseGroup>
  );
}

const styles = StyleSheet.create({
  list: { minWidth: 0 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  copy: { minWidth: 0, flex: 1, gap: 7 },
  secondary: { width: '38%' },
});
