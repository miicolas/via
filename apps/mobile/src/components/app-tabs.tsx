import { NativeTabs } from 'expo-router/unstable-native-tabs';

import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';

export default function AppTabs() {
  const { colors } = useHomeMapTheme();

  return (
    <NativeTabs
      backgroundColor="transparent"
      blurEffect="none"
      disableTransparentOnScrollEdge
      labelStyle={{ selected: { color: colors.primary } }}
      shadowColor="transparent"
      tintColor={colors.primary}
      unstable_nativeProps={{
        nativeContainerStyle: { backgroundColor: 'transparent' },
      }}>
      <NativeTabs.Trigger name="map">
        <NativeTabs.Trigger.Label>Carte</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'map', selected: 'map.fill' }} />
      </NativeTabs.Trigger>

      <NativeTabs.Trigger name="explore">
        <NativeTabs.Trigger.Label>Lignes</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'tram', selected: 'tram.fill' }} />
      </NativeTabs.Trigger>

      <NativeTabs.Trigger name="navigo">
        <NativeTabs.Trigger.Label>Navigo</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'creditcard', selected: 'creditcard.fill' }} />
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
