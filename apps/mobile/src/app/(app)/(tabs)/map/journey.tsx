import { Stack, useRouter } from 'expo-router';
import { useHeaderHeight } from 'expo-router/react-navigation';
import { useCallback, useEffect } from 'react';

import { ChatScreen } from '@/features/chat/components/chat-screen';
import { JourneySheetScreen } from '@/features/journey/components/sheet-screen';
import { useMap } from '@/features/map/hooks/use-map';
import { isJourneyScreen } from '@/features/map/model/journey-screen';

/** The single native sheet route reused by results, detail and Via chat. */
export default function MapJourneyScreen() {
  const router = useRouter();
  const toolbarHeight = useHeaderHeight();
  const {
    cancelJourney,
    chatOpen,
    closeChat,
    closeJourneyDetail,
    journey,
    screen,
  } = useMap();
  const showingDetail = screen === 'detail' && journey.status === 'ready';

  const goBack = useCallback(() => {
    if (chatOpen) {
      closeChat();
      if (isJourneyScreen(screen)) return;
    }

    if (showingDetail) {
      closeJourneyDetail();
      return;
    }

    cancelJourney();
    router.dismiss();
  }, [cancelJourney, chatOpen, closeChat, closeJourneyDetail, router, screen, showingDetail]);

  useEffect(() => {
    return () => {
      closeChat();
      cancelJourney();
    };
  }, [cancelJourney, closeChat]);

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
        <Stack.Toolbar.Button icon="xmark" onPress={goBack} />
      </Stack.Toolbar>
      {chatOpen ? (
        <ChatScreen toolbarHeight={toolbarHeight} />
      ) : (
        <JourneySheetScreen toolbarHeight={toolbarHeight} />
      )}
    </>
  );
}
