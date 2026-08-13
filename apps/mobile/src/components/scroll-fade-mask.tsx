import MaskedView from '@react-native-masked-view/masked-view';
import type { PropsWithChildren } from 'react';
import { Platform, StyleSheet, View } from 'react-native';

import { ScrollFadeEdge } from '@/components/scroll-fade-edge';

type ScrollFadeMaskProps = PropsWithChildren<{
  bottom: boolean;
  top: boolean;
}>;

/** Fades scroll content to transparent without painting over the sheet material. */
export function ScrollFadeMask({ bottom, children, top }: ScrollFadeMaskProps) {
  // Android fades natively through the ScrollView's `fadingEdgeLength`.
  if (Platform.OS === 'android') {
    return <View style={styles.container}>{children}</View>;
  }

  return (
    <MaskedView
      style={styles.container}
      maskElement={
        <View style={styles.mask}>
          {top ? <ScrollFadeEdge edge="top" /> : null}
          <View style={styles.opaqueMask} />
          {bottom ? <ScrollFadeEdge edge="bottom" /> : null}
        </View>
      }
    >
      {children}
    </MaskedView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  mask: { flex: 1 },
  opaqueMask: { flex: 1, backgroundColor: '#000000' },
});
