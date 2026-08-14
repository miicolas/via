import { Stack, useRouter } from 'expo-router';
import { useCallback, useRef } from 'react';

import { MetroMapScreen } from '@/components/map/metro-map-screen';

export default function MapScreen() {
  const router = useRouter();
  const recenterRef = useRef<(() => void) | null>(null);
  const setRecenter = useCallback((recenter: () => void) => {
    recenterRef.current = recenter;
  }, []);
  const openJourneySheet = useCallback(() => {
    router.navigate('/map/journey');
  }, [router]);
  const recenter = useCallback(() => {
    if (recenterRef.current) {
      recenterRef.current();
    }
  }, []);

  return (
    <>
      <Stack.Screen
        options={{
          headerBackVisible: false,
          headerShown: true,
          headerShadowVisible: false,
          headerTitle: '',
          headerTransparent: true,
          title: '',
        }}
      />
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button
          accessibilityLabel="Recentrer la carte sur ma position"
          icon="location.fill"
          onPress={recenter}
        />
      </Stack.Toolbar>
      <MetroMapScreen
        onJourneyOpen={openJourneySheet}
        onRecenterReady={setRecenter}
      />
    </>
  );
}
