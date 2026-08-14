import { Stack } from 'expo-router/stack';

import { ViaChatProvider } from '@/features/chat/state/provider';
import { MapProvider } from '@/features/map/state/provider';

export const unstable_settings = {
  anchor: 'index',
};

export default function AppLayout() {
  return (
    <MapProvider>
      <ViaChatProvider>
        <Stack screenOptions={{ animation: 'none', headerShown: false }}>
          <Stack.Screen name="index" />
          <Stack.Screen name="(tabs)" />
        </Stack>
      </ViaChatProvider>
    </MapProvider>
  );
}
