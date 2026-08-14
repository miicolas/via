import { Host } from '@expo/ui';
import { StyleSheet } from 'react-native';

import { Button } from '@/components/button';
import { useAppTheme } from '@/hooks/use-app-theme';

type RecenterButtonProps = {
  isLoading?: boolean;
  onPress: () => void;
};

export function RecenterButton({ isLoading = false, onPress }: RecenterButtonProps) {
  const { colors } = useAppTheme();

  return (
    <Host matchContents style={styles.host}>
      <Button
        accessibilityHint="Recentre la carte sur votre position"
        accessibilityLabel={
          isLoading ? 'Localisation en cours' : 'Recentrer la carte sur ma position'
        }
        disabled={isLoading}
        embedded
        iconOnly
        label={isLoading ? 'Localisation en cours' : 'Ma position'}
        onPress={onPress}
        shape="circle"
        size="large"
        systemImage="location.fill"
        tint={colors.primary}
        variant="glass"
      />
    </Host>
  );
}

const styles = StyleSheet.create({
  host: {
    minHeight: 48,
    minWidth: 44,
  },
});
