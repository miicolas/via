import type { JourneysResponse } from '@via/contract';
import type { UIMessage } from 'ai';

/** What the chat's `data-itinerary` part carries: the exact computed itinerary. */
export type ItineraryData = {
  destination: {
    kind: 'station' | 'address';
    id: string;
    name: string;
    latitude: number;
    longitude: number;
    context?: string;
  };
  requestedAt?: string;
  datetimeRepresents?: 'departure' | 'arrival';
  response: JourneysResponse;
};

/** The latest itinerary Via computed in this conversation, if any. */
export function latestItinerary(messages: UIMessage[]): ItineraryData | undefined {
  const part = messages
    .flatMap((message) => message.parts)
    .filter((candidate) => candidate.type === 'data-itinerary')
    .at(-1) as { data?: ItineraryData } | undefined;
  if (part?.data) return part.data;

  const assistant = [...messages].reverse().find((message) => message.role === 'assistant');
  return (assistant?.metadata as { itinerary?: ItineraryData } | undefined)?.itinerary;
}
