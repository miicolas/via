import { Button, Host, Text, VStack } from '@expo/ui/swift-ui';
import {
  accessibilityLabel,
  buttonBorderShape,
  buttonStyle,
  font,
  foregroundStyle,
  frame,
  glassEffect,
  multilineTextAlignment,
  padding,
  tint,
} from '@expo/ui/swift-ui/modifiers';
import { StyleSheet } from 'react-native';

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
            frame({ maxWidth: 250 }),
          ]}>
          {message}
        </Text>
        <Button
          onPress={onRetry}
          modifiers={[
            accessibilityLabel('Réessayer de charger le réseau'),
            buttonStyle('glassProminent'),
            buttonBorderShape('capsule'),
            tint(colors.primary),
          ]}>
          <Text
            modifiers={[
              font({ size: 14, weight: 'semibold' }),
              frame({ minHeight: 32 }),
              padding({ horizontal: 6 }),
            ]}>
            Réessayer
          </Text>
        </Button>
      </VStack>
    </Host>
  );
}

const styles = StyleSheet.create({
  host: { minHeight: 44 },
});
