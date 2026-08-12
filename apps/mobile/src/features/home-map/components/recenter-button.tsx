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

import { HomeMapTheme } from '@/features/home-map/styles/theme';

type HomeRecenterButtonProps = {
  isLoading?: boolean;
  onPress: () => void;
};

/**
 * A native SwiftUI glass button. The previous GlassView + Pressable pair ran
 * two competing press animations — the native glass one over a snapshot, the
 * RN scale on the live content — and the button showed doubled while pressed.
 * SwiftUI's glass button style owns the whole press, so there is one copy.
 */
export function HomeRecenterButton({ isLoading = false, onPress }: HomeRecenterButtonProps) {
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
            <ProgressView modifiers={[tint(HomeMapTheme.primary)]} />
          ) : (
            <Image color={HomeMapTheme.primary} size={15} systemName="location.fill" />
          )}
          <Text
            modifiers={[font({ size: 14, weight: 'semibold' }), foregroundStyle(HomeMapTheme.ink)]}>
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
