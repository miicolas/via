import { StyleSheet, View } from 'react-native';

export const SCROLL_FADE_HEIGHT = 44;

type ScrollFadeEdgeProps = {
  edge: 'bottom' | 'top';
};

/** Gradient slice of a scroll mask: opaque toward the content, transparent toward the cut. */
export function ScrollFadeEdge({ edge }: ScrollFadeEdgeProps) {
  const direction = edge === 'top' ? 'to bottom' : 'to top';

  return (
    <View
      style={[
        styles.fade,
        {
          experimental_backgroundImage: `linear-gradient(${direction}, rgba(0, 0, 0, 0), rgba(0, 0, 0, 1))`,
        },
      ]}
    />
  );
}

const styles = StyleSheet.create({
  fade: { height: SCROLL_FADE_HEIGHT },
});
