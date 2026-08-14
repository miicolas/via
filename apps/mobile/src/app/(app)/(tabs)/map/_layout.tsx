import { Stack } from 'expo-router/stack';

import { MAP_JOURNEY_SHEET_DETENTS } from '@/features/map/model/overview-sheet';

export default function MapLayout() {
  return (
    <Stack screenOptions={{ animation: 'none', headerShown: false }}>
      <Stack.Screen
        name="index"
        options={{
          contentStyle: { backgroundColor: 'transparent' },
          headerBackVisible: false,
          headerShadowVisible: false,
          headerTransparent: true,
          headerTitle: '',
          title: '',
        }}
      />
      <Stack.Screen
        name="journey"
        options={{
          contentStyle: { backgroundColor: 'transparent' },
          headerBackVisible: false,
          headerShadowVisible: false,
          headerShown: true,
          headerTransparent: true,
          headerTitle: '',
          presentation: 'formSheet',
          sheetAllowedDetents: [...MAP_JOURNEY_SHEET_DETENTS],
          sheetCornerRadius: 28,
          sheetGrabberVisible: true,
          sheetInitialDetentIndex: MAP_JOURNEY_SHEET_DETENTS.length - 1,
          sheetLargestUndimmedDetentIndex: 'last',
          title: '',
        }}
      />
    </Stack>
  );
}
