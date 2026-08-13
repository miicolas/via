import { ActivityIndicator, StyleSheet, View } from 'react-native';

import { useAppTheme } from '@/hooks/use-app-theme';

export function SheetLoadingSkeleton() {
  const { colors } = useAppTheme();

  return (
    <View
      accessibilityLabel="Chargement des données du réseau"
      accessibilityRole="progressbar"
      style={styles.container}>
      <ActivityIndicator color={colors.primary} size="large" />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center' },
});
