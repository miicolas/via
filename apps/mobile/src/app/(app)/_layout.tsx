import { Stack } from 'expo-router/stack';
import { Platform } from 'react-native';

import {
  MAP_OVERVIEW_SHEET_DETENTS,
  MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
} from '@/features/home-map/model/overview-sheet';
import { HomeMapProvider } from '@/features/home-map/state/provider';

export const unstable_settings = {
  anchor: 'index',
};

export default function AppLayout() {
  return (
    <HomeMapProvider>
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="index" />
        <Stack.Screen
          name="(tabs)"
          options={
            Platform.OS === 'ios'
              ? {
                  contentStyle: { backgroundColor: 'transparent' },
                  gestureEnabled: false,
                  presentation: 'formSheet',
                  sheetAllowedDetents: [...MAP_OVERVIEW_SHEET_DETENTS],
                  sheetCornerRadius: 28,
                  sheetGrabberVisible: true,
                  sheetInitialDetentIndex: MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
                  sheetLargestUndimmedDetentIndex: 'last',
                }
              : { presentation: 'card' }
          }
        />
      </Stack>
    </HomeMapProvider>
  );
}
