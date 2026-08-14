import { useChat } from '@ai-sdk/react';
import type { Coordinate } from '@via/contract';
import { DefaultChatTransport } from 'ai';
import { fetch as expoFetch } from 'expo/fetch';
import { useMemo } from 'react';

import type { ItineraryData } from '@/features/chat/model/latest-itinerary';
import { apiBaseUrl } from '@/lib/api';
import { getClientIdentity } from '@/lib/client-identity';

/**
 * The Via conversation, streamed from `/ai/chat`. `expo/fetch` is required:
 * React Native's built-in fetch buffers the body, which would turn the stream
 * back into one blocking response. The latest transport follows GPS updates;
 * `useChat` keeps the conversation itself stable across those updates.
 */
export function useViaChat(
  location: Coordinate | undefined,
  onItinerary: (itinerary: ItineraryData) => void
) {
  const transport = useMemo(() => {
    const identifiedFetch = (async (
      input: Parameters<typeof expoFetch>[0],
      init?: Parameters<typeof expoFetch>[1]
    ) => {
      const identity = await getClientIdentity();
      return expoFetch(input, {
        ...init,
        headers: {
          ...(init?.headers as Record<string, string> | undefined),
          'x-via-client-id': identity,
        },
      });
    }) as unknown as typeof globalThis.fetch;
    return new DefaultChatTransport({
      api: `${apiBaseUrl}/ai/chat`,
      fetch: identifiedFetch,
      prepareSendMessagesRequest: ({ messages }) => ({
        body: { messages, location },
      }),
    });
  }, [location]);

  return useChat({
    transport,
    onData: (part) => {
      if (part.type === 'data-itinerary') onItinerary(part.data as ItineraryData);
    },
  });
}
