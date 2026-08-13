import { Stack } from 'expo-router/stack';

import { MapProvider } from '@/features/map/state/provider';

export default function AppLayout() {
  return (
    <MapProvider>
      <Stack screenOptions={{ animation: 'none', headerShown: false }}>
        <Stack.Screen name="index" />
        <Stack.Screen name="(tabs)" />
      </Stack>
    </MapProvider>
  );
}
