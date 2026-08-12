import { Host } from '@expo/ui';
import { Button, ContentUnavailableView, VStack } from '@expo/ui/swift-ui';
import { buttonBorderShape, buttonStyle, padding, tint } from '@expo/ui/swift-ui/modifiers';
import type { SFSymbol } from 'expo-symbols';
import { StyleSheet } from 'react-native';

import { HomeMapTheme } from '@/features/home-map/theme';

type HomeUnavailableStateProps = {
  actionLabel?: string;
  description: string;
  icon: SFSymbol;
  onAction?: () => void;
  title: string;
};

export function HomeUnavailableState({
  actionLabel,
  description,
  icon,
  onAction,
  title,
}: HomeUnavailableStateProps) {
  return (
    <Host colorScheme="light" seedColor={HomeMapTheme.primary} style={styles.host}>
      <VStack alignment="center" spacing={12} modifiers={[padding({ horizontal: 24 })]}>
        <ContentUnavailableView description={description} systemImage={icon} title={title} />
        {actionLabel && onAction ? (
          <Button
            label={actionLabel}
            onPress={onAction}
            modifiers={[
              buttonStyle('borderedProminent'),
              buttonBorderShape('capsule'),
              tint(HomeMapTheme.primary),
            ]}
          />
        ) : null}
      </VStack>
    </Host>
  );
}

const styles = StyleSheet.create({
  host: {
    flex: 1,
    minHeight: 260,
    justifyContent: 'center',
  },
});
