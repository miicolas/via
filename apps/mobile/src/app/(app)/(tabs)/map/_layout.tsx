import { Stack } from 'expo-router';

import { HomeMapProvider } from '@/features/home-map/provider';

export const unstable_settings = {
  initialRouteName: 'index',
};

export default function MapLayout() {
  return (
    <HomeMapProvider>
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="index" />
        <Stack.Screen
          name="overview"
          options={{
            contentStyle: { backgroundColor: 'transparent' },
            presentation: 'formSheet',
            sheetAllowedDetents: [0.72, 0.94],
            sheetCornerRadius: 40,
            sheetGrabberVisible: true,
            sheetInitialDetentIndex: 0,
            sheetLargestUndimmedDetentIndex: 'last',
          }}
        />
      </Stack>
    </HomeMapProvider>
  );
}
