import { usePathname, useRouter, type Href } from 'expo-router';
import { NativeTabs } from 'expo-router/unstable-native-tabs';
import { SymbolView } from 'expo-symbols';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';

/** The map overview form sheet the accessory opens. */
const MAP_OVERVIEW_HREF = '/map/overview' as Href;

export function MapBottomAccessory() {
  const { colors } = useHomeMapTheme();
  const pathname = usePathname();
  const placement = NativeTabs.BottomAccessory.usePlacement();
  const router = useRouter();

  // Keep the accessory mounted while the form sheet is presented. NativeTabs
  // keeps both accessory placements alive, and unmounting it on `/map/overview`
  // can leave the regular placement without a working press target after dismiss.
  if (!pathname.startsWith('/map')) return null;

  const button = (
    <Pressable
      accessibilityHint="Ouvre le panneau des stations à proximité"
      accessibilityLabel="Rechercher une station"
      accessibilityRole="button"
      onPress={() => router.push(MAP_OVERVIEW_HREF)}
      style={({ pressed }) => [
        styles.button,
        placement === 'inline' && styles.inlineButton,
        pressed && styles.pressed,
      ]}>
      <SymbolView
        name={{ ios: 'magnifyingglass', android: 'search' }}
        size={19}
        tintColor={colors.primary}
        weight="semibold"
      />
      {placement === 'regular' ? (
        <>
          <Text numberOfLines={1} style={[styles.title, { color: colors.ink }]}>
            Où allez-vous ?
          </Text>
          <SymbolView
            name={{ ios: 'chevron.up', android: 'keyboard_arrow_up' }}
            size={14}
            tintColor={colors.muted}
            weight="semibold"
          />
        </>
      ) : null}
    </Pressable>
  );

  // The regular placement needs a flex wrapper so the Pressable fills the
  // accessory host; the inline placement must stay a compact native control.
  return placement === 'regular' ? <View style={styles.accessory}>{button}</View> : button;
}

const styles = StyleSheet.create({
  accessory: { flex: 1 },
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
    fontFamily: 'Inter_600SemiBold',
    fontSize: 16,
    lineHeight: 20,
  },
  pressed: { transform: [{ scale: 0.985 }] },
});
