import type { PropsWithChildren } from 'react';
import { useCallback, useMemo, useState } from 'react';

import { useViaChat } from '@/features/chat/hooks/use-via-chat';
import type { ItineraryData } from '@/features/chat/model/latest-itinerary';
import { ViaChatContext, type ViaChatValue } from '@/features/chat/state/context';
import { useMap } from '@/features/map/hooks/use-map';

/**
 * One shared Via conversation for the whole app: the inline answer card and
 * the "Répondre" screen read the same transcript, so following up keeps the
 * context of what the card already answered.
 */
export function ViaChatProvider({ children }: PropsWithChildren) {
  const { userLocation } = useMap();
  const location = userLocation.status === 'ready' ? userLocation.coordinate : undefined;
  const [itinerary, setItinerary] = useState<ItineraryData>();
  const receiveItinerary = useCallback((next: ItineraryData) => setItinerary(next), []);
  const { error, messages, sendMessage, setMessages, status } = useViaChat(
    location,
    receiveItinerary
  );
  const reset = useCallback(() => {
    setItinerary(undefined);
    setMessages([]);
  }, [setMessages]);

  const ask = useCallback(
    (phrase: string) => {
      reset();
      void sendMessage({ text: phrase });
    },
    [reset, sendMessage]
  );

  const send = useCallback((text: string) => void sendMessage({ text }), [sendMessage]);

  const value = useMemo<ViaChatValue>(
    () => ({ messages, status, error, itinerary, ask, reset, send }),
    [ask, error, itinerary, messages, reset, send, status]
  );

  return <ViaChatContext.Provider value={value}>{children}</ViaChatContext.Provider>;
}
