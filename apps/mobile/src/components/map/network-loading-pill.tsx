import { Host, HStack, ProgressView, Text } from '@expo/ui/swift-ui';
import {
  font,
  foregroundStyle,
  frame,
  glassEffect,
  padding,
  tint,
} from '@expo/ui/swift-ui/modifiers';
import { StyleSheet } from 'react-native';

import { useAppTheme } from '@/hooks/use-app-theme';

/** Slim Liquid Glass capsule shown over the map while the metro network loads. */
export function NetworkLoadingPill() {
  const { colors } = useAppTheme();

  return (
    <Host matchContents style={styles.host}>
      <HStack
        spacing={8}
        modifiers={[
          frame({ minHeight: 36 }),
          padding({ horizontal: 14 }),
          glassEffect({ glass: { variant: 'regular' }, shape: 'capsule' }),
        ]}>
        <ProgressView modifiers={[tint(colors.primary)]} />
        <Text modifiers={[font({ size: 14, weight: 'semibold' }), foregroundStyle(colors.ink)]}>
          Chargement du réseau…
        </Text>
      </HStack>
    </Host>
  );
}

const styles = StyleSheet.create({
  host: { minHeight: 44 },
});
