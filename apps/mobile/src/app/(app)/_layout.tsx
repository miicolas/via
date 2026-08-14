import { Stack } from 'expo-router/stack';

import { ViaChatProvider } from '@/features/chat/state/provider';
import { MapProvider } from '@/features/map/state/provider';

export default function AppLayout() {
  return (
    <MapProvider>
      <ViaChatProvider>
        <Stack screenOptions={{ animation: 'none', headerShown: false }}>
        <Stack.Screen name="index" />
        <Stack.Screen name="(tabs)" />
          <Stack.Screen
            name="chat"
            options={{ animation: 'slide_from_bottom', presentation: 'modal' }}
          />
        </Stack>
      </ViaChatProvider>
    </MapProvider>
  );
}
