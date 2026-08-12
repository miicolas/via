import { ActivityIndicator, StyleSheet, View } from 'react-native';

import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';

export function SheetLoadingSkeleton() {
  const { colors } = useHomeMapTheme();

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
