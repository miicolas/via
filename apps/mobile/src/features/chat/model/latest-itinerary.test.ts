import type { UIMessage } from 'ai';
import { expect, test } from 'bun:test';

import {
  latestItinerary,
  type ItineraryData,
} from '@/features/chat/model/latest-itinerary';

const itinerary: ItineraryData = {
  destination: {
    kind: 'station',
    id: 'IDFM:64483',
    name: 'Chatou - Croissy',
    latitude: 48.885,
    longitude: 2.155,
  },
  requestedAt: '2026-08-15T07:00:00+02:00',
  datetimeRepresents: 'departure',
  response: {
    status: 'ready',
    source: 'idfm-realtime',
    generatedAt: '2026-08-14T14:00:00+02:00',
    journeys: [],
  },
};

test('reads the itinerary kept on the final assistant message', () => {
  const messages: UIMessage[] = [
    {
      id: 'answer',
      role: 'assistant',
      metadata: { itinerary },
      parts: [{ type: 'text', text: 'Prends le RER A.' }],
    },
  ];

  expect(latestItinerary(messages)).toEqual(itinerary);
});
