import { GlassView } from 'expo-glass-effect';
import { SymbolView } from 'expo-symbols';
import { ActivityIndicator, Pressable, StyleSheet, Text } from 'react-native';

import { HomeMapTheme } from '@/features/home-map/theme';

type HomeRecenterButtonProps = {
  isLoading?: boolean;
  onPress: () => void;
};

export function HomeRecenterButton({ isLoading = false, onPress }: HomeRecenterButtonProps) {
  return (
    <GlassView
      glassEffectStyle="regular"
      isInteractive
      style={styles.glass}
      tintColor="#F2F0E966">
      <Pressable
        accessibilityLabel="Recentrer la carte sur ma position"
        accessibilityRole="button"
        accessibilityState={{ busy: isLoading }}
        disabled={isLoading}
        hitSlop={8}
        onPress={onPress}
        style={({ pressed }) => [styles.button, pressed && styles.pressed]}>
        {isLoading ? (
          <ActivityIndicator color={HomeMapTheme.primary} size="small" />
        ) : (
          <SymbolView
            name={{ ios: 'location.fill', android: 'my_location' }}
            size={18}
            tintColor={HomeMapTheme.primary}
            weight="semibold"
          />
        )}
        <Text style={styles.label}>{isLoading ? 'Localisation…' : 'Ma position'}</Text>
      </Pressable>
    </GlassView>
  );
}

const styles = StyleSheet.create({
  glass: {
    minHeight: 48,
    borderRadius: 24,
    borderCurve: 'continuous',
    backgroundColor: process.env.EXPO_OS === 'ios' ? 'transparent' : HomeMapTheme.surface,
    boxShadow: '0 2px 12px rgba(22, 26, 24, 0.16)',
  },
  button: {
    minHeight: 48,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    paddingHorizontal: 16,
    borderRadius: 24,
    borderCurve: 'continuous',
  },
  label: {
    color: HomeMapTheme.ink,
    fontFamily: 'Inter_600SemiBold',
    fontSize: 14,
    lineHeight: 18,
  },
  pressed: { transform: [{ scale: 0.97 }] },
});
