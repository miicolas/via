import { MetroMapScreen } from '@/components/map/metro-map-screen';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';
import { StyleSheet } from 'react-native';

/**
 * The platform gate, and nothing else.
 *
 * It used to sit ten lines *below* `useNetworkMap()`, so Android and web mounted
 * the hook, fired the ~890 kB network request, and threw the answer away before
 * rendering this message. Hooks cannot be called conditionally, so the screen
 * that owns them is a separate module.
 */
export default function MapScreen() {
  if (process.env.EXPO_OS !== 'ios') {
    return (
      <ThemedView style={styles.unsupported}>
        <ThemedText type="subtitle">Carte disponible sur iPhone</ThemedText>
        <ThemedText themeColor="textSecondary" style={styles.centerText}>
          Cette première intégration est optimisée exclusivement pour iOS.
        </ThemedText>
      </ThemedView>
    );
  }

  return <MetroMapScreen />;
}

const styles = StyleSheet.create({
  unsupported: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.two,
    paddingHorizontal: Spacing.four,
  },
  centerText: { textAlign: 'center' },
});
