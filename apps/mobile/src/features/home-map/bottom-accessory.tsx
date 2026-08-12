import { type Href, usePathname, useRouter } from 'expo-router';
import { NativeTabs } from 'expo-router/unstable-native-tabs';
import { SymbolView } from 'expo-symbols';
import { Pressable, StyleSheet, Text } from 'react-native';

import { HomeMapTheme } from '@/features/home-map/theme';

const overviewHref = '/map/overview' as Href;

export function MapBottomAccessory() {
  const pathname = usePathname();
  const placement = NativeTabs.BottomAccessory.usePlacement();
  const router = useRouter();

  if (!pathname.startsWith('/map') || pathname.includes('/overview')) return null;

  return (
    <Pressable
      accessibilityHint="Ouvre le panneau des stations à proximité"
      accessibilityLabel="Rechercher une station"
      accessibilityRole="button"
      onPress={() => router.push(overviewHref)}
      style={({ pressed }) => [
        styles.button,
        placement === 'inline' && styles.inlineButton,
        pressed && styles.pressed,
      ]}>
      <SymbolView
        name={{ ios: 'magnifyingglass', android: 'search' }}
        size={19}
        tintColor={HomeMapTheme.primary}
        weight="semibold"
      />
      {placement === 'regular' ? (
        <>
          <Text numberOfLines={1} style={styles.title}>
            Où allez-vous ?
          </Text>
          <SymbolView
            name={{ ios: 'chevron.up', android: 'keyboard_arrow_up' }}
            size={14}
            tintColor={HomeMapTheme.muted}
            weight="semibold"
          />
        </>
      ) : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    flex: 1,
    minHeight: 44,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 18,
  },
  inlineButton: {
    minWidth: 44,
    justifyContent: 'center',
    paddingHorizontal: 10,
  },
  title: {
    flex: 1,
    color: HomeMapTheme.ink,
    fontFamily: 'Inter_600SemiBold',
    fontSize: 16,
    lineHeight: 20,
  },
  pressed: { transform: [{ scale: 0.985 }] },
});
