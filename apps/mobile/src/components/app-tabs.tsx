import { NativeTabs } from 'expo-router/unstable-native-tabs';

import { MapBottomAccessory } from '@/features/home-map/components/bottom-accessory';

export default function AppTabs() {
  return (
    <NativeTabs
      disableTransparentOnScrollEdge
      labelStyle={{ selected: { color: '#2F6B5B' } }}
      tintColor="#2F6B5B">
      <NativeTabs.BottomAccessory>
        <MapBottomAccessory />
      </NativeTabs.BottomAccessory>

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
