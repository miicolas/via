import type { UIMessage } from 'ai';
import { createContext } from 'react';

import type { ItineraryData } from '@/features/chat/model/latest-itinerary';

export type ViaChatValue = {
  messages: UIMessage[];
  status: 'submitted' | 'streaming' | 'ready' | 'error';
  error: Error | undefined;
  itinerary: ItineraryData | undefined;
  /** Starts a fresh exchange: clears the transcript, then sends the phrase. */
  ask: (phrase: string) => void;
  /** Continues the current conversation (the "Répondre" surface). */
  send: (text: string) => void;
  /** Clears the current Via exchange and its streamed itinerary. */
  reset: () => void;
};

export const ViaChatContext = createContext<ViaChatValue | undefined>(undefined);
