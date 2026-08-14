import { Host } from '@expo/ui';
import { Text, VStack } from '@expo/ui/swift-ui';
import {
  fixedSize,
  font,
  foregroundStyle,
  frame,
  glassEffect,
  multilineTextAlignment,
  padding,
} from '@expo/ui/swift-ui/modifiers';
import { StyleSheet } from 'react-native';

import { Button } from '@/components/button';
import { useAppTheme } from '@/hooks/use-app-theme';

type NetworkErrorCardProps = {
  message: string;
  onRetry: () => void;
};

/** Liquid Glass card shown over the map when the metro network failed to load. */
export function NetworkErrorCard({ message, onRetry }: NetworkErrorCardProps) {
  const { colors } = useAppTheme();

  return (
    <Host matchContents style={styles.host}>
      <VStack
        spacing={14}
        modifiers={[
          padding({ horizontal: 20, vertical: 18 }),
          glassEffect({ glass: { variant: 'regular' }, shape: 'roundedRectangle', cornerRadius: 26 }),
        ]}>
        <Text
          modifiers={[
            font({ size: 14 }),
            foregroundStyle(colors.ink),
            multilineTextAlignment('center'),
            // A fixed width (not maxWidth) so matchContents measures the wrapped height.
            frame({ width: 240 }),
            fixedSize({ horizontal: false, vertical: true }),
          ]}>
          {message}
        </Text>
        <Button
          embedded
          label="Réessayer"
          onPress={onRetry}
          size="large"
          tint={colors.primary}
          variant="prominent"
        />
      </VStack>
    </Host>
  );
}

const styles = StyleSheet.create({
  host: { minHeight: 44 },
});
