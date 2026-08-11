import { ActivityIndicator, Pressable, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { Spacing } from '@/constants/theme';

type MapStatusProps = {
  error: string | undefined;
  onRetry: () => void;
};

/** Centred overlay shown while the network loads, or when it failed to. */
export function MapStatus({ error, onRetry }: MapStatusProps) {
  return (
    <View style={styles.status} accessibilityLiveRegion="polite">
      {error ? (
        <>
          <ThemedText style={styles.centerText}>{error}</ThemedText>
          <Pressable
            accessibilityRole="button"
            onPress={onRetry}
            style={({ pressed }) => [styles.retry, pressed && styles.pressed]}
          >
            <ThemedText type="smallBold">Réessayer</ThemedText>
          </Pressable>
        </>
      ) : (
        <>
          <ActivityIndicator color="#1D1D1F" />
          <ThemedText type="small">Chargement du réseau…</ThemedText>
        </>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  status: {
    position: 'absolute',
    top: '45%',
    alignSelf: 'center',
    minWidth: 220,
    alignItems: 'center',
    gap: Spacing.two,
    padding: Spacing.three,
    borderRadius: 16,
    borderCurve: 'continuous',
    backgroundColor: 'rgba(255,255,255,0.96)',
  },
  retry: {
    minHeight: 44,
    justifyContent: 'center',
    paddingHorizontal: Spacing.three,
    borderRadius: 22,
    backgroundColor: '#FFBE00',
  },
  pressed: { opacity: 0.6 },
  centerText: { textAlign: 'center' },
});
