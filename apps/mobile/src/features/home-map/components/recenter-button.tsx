import { Button, Host, HStack, Image, ProgressView, Text } from '@expo/ui/swift-ui';
import {
  accessibilityLabel,
  buttonBorderShape,
  buttonStyle,
  disabled,
  font,
  foregroundStyle,
  frame,
  padding,
  tint,
} from '@expo/ui/swift-ui/modifiers';
import { StyleSheet } from 'react-native';

import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';

type HomeRecenterButtonProps = {
  isLoading?: boolean;
  onPress: () => void;
};

export function HomeRecenterButton({ isLoading = false, onPress }: HomeRecenterButtonProps) {
  const { colors } = useHomeMapTheme();

  return (
    <Host matchContents style={styles.host}>
      <Button
        onPress={onPress}
        modifiers={[
          accessibilityLabel('Recentrer la carte sur ma position'),
          buttonStyle('glass'),
          buttonBorderShape('capsule'),
          disabled(isLoading),
        ]}>
        <HStack spacing={8} modifiers={[frame({ minHeight: 32 }), padding({ horizontal: 6 })]}>
          {isLoading ? (
            <ProgressView modifiers={[tint(colors.primary)]} />
          ) : (
            <Image color={colors.primary} size={15} systemName="location.fill" />
          )}
          <Text
            modifiers={[font({ size: 14, weight: 'semibold' }), foregroundStyle(colors.ink)]}>
            {isLoading ? 'Localisation…' : 'Ma position'}
          </Text>
        </HStack>
      </Button>
    </Host>
  );
}

const styles = StyleSheet.create({
  host: {
    minHeight: 48,
    minWidth: 44,
  },
});
