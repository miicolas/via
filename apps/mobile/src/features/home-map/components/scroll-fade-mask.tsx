import { MaskedView } from '@expo/ui/community/masked-view';
import { Host, Rectangle } from '@expo/ui/swift-ui';
import { foregroundStyle } from '@expo/ui/swift-ui/modifiers';
import type { PropsWithChildren } from 'react';
import { StyleSheet, View } from 'react-native';

type ScrollFadeMaskProps = PropsWithChildren<{
  active: boolean;
}>;

/** Fades scroll content to transparent without painting over the sheet material. */
export function ScrollFadeMask({ active, children }: ScrollFadeMaskProps) {
  return (
    <MaskedView
      style={styles.container}
      maskElement={
        active ? (
          <View style={styles.mask}>
            <Host ignoreSafeArea="all" style={styles.fade}>
              <Rectangle
                modifiers={[
                  foregroundStyle({
                    type: 'linearGradient',
                    colors: ['transparent', '#000000'],
                    startPoint: { x: 0.5, y: 0 },
                    endPoint: { x: 0.5, y: 1 },
                  }),
                ]}
              />
            </Host>
            <View style={styles.opaqueMask} />
          </View>
        ) : (
          <View style={styles.opaqueMask} />
        )
      }
    >
      {children}
    </MaskedView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  mask: { flex: 1 },
  fade: { height: 44 },
  opaqueMask: { flex: 1, backgroundColor: '#000000' },
});
