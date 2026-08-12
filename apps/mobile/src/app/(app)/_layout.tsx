import { Stack } from 'expo-router/stack';

import { HomeMapProvider } from '@/features/home-map/state/provider';

export default function AppLayout() {
  return (
    <HomeMapProvider>
      <Stack screenOptions={{ animation: 'none', headerShown: false }}>
        <Stack.Screen name="index" />
        <Stack.Screen name="(tabs)" />
      </Stack>
    </HomeMapProvider>
  );
}
