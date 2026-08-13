import { Host, Rectangle } from '@expo/ui/swift-ui';
import { foregroundStyle } from '@expo/ui/swift-ui/modifiers';
import { StyleSheet } from 'react-native';

export const SCROLL_FADE_HEIGHT = 44;

type ScrollFadeEdgeProps = {
  edge: 'bottom' | 'top';
};

/** Gradient slice of a scroll mask: opaque toward the content, transparent toward the cut. */
export function ScrollFadeEdge({ edge }: ScrollFadeEdgeProps) {
  const colors = edge === 'top' ? ['transparent', '#000000'] : ['#000000', 'transparent'];

  return (
    <Host ignoreSafeArea="all" style={styles.fade}>
      <Rectangle
        modifiers={[
          foregroundStyle({
            type: 'linearGradient',
            colors,
            startPoint: { x: 0.5, y: 0 },
            endPoint: { x: 0.5, y: 1 },
          }),
        ]}
      />
    </Host>
  );
}

const styles = StyleSheet.create({
  fade: { height: SCROLL_FADE_HEIGHT },
});
