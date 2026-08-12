import { Stack } from 'expo-router';

import {
  MAP_OVERVIEW_SHEET_DETENTS,
  MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
} from '@/features/home-map/model/overview-sheet';

export const unstable_settings = {
  initialRouteName: 'index',
};

export default function MapLayout() {
  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="index" />
      <Stack.Screen
        name="overview"
        options={{
          contentStyle: { backgroundColor: 'transparent' },
          presentation: 'formSheet',
          sheetAllowedDetents: [...MAP_OVERVIEW_SHEET_DETENTS],
          sheetCornerRadius: 28,
          sheetGrabberVisible: true,
          sheetInitialDetentIndex: MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
          sheetLargestUndimmedDetentIndex: 'last',
        }}
      />
    </Stack>
  );
}
