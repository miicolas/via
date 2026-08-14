import { StyleSheet, View } from 'react-native';

import { PulseBlock } from '@/components/pulse-block';
import { PulseGroup } from '@/components/pulse-group';

/** The "Via is working" shimmer under the streaming answer. */
export function ViaAnswerSkeleton() {
  return (
    <PulseGroup style={styles.group}>
      <View
        accessibilityLabel="Via prépare la réponse"
        accessibilityRole="progressbar"
        style={styles.bars}>
        <PulseBlock height={20} radius={5} style={styles.tick} />
        <PulseBlock height={11} radius={5} style={styles.wide} />
        <PulseBlock height={11} radius={5} style={styles.narrow} />
      </View>
    </PulseGroup>
  );
}

const styles = StyleSheet.create({
  group: { minWidth: 0 },
  bars: { gap: 10 },
  tick: { width: 10 },
  wide: { width: '82%' },
  narrow: { width: '46%' },
});
