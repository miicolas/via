import { expect, test } from 'bun:test';

import { nativeChatEventSchema, nativeChatRequestSchema } from './schema';

test('native chat request accepts only user and assistant messages', () => {
  expect(
    nativeChatRequestSchema.safeParse({
      messages: [
        { role: 'user', content: 'Comment aller à Châtelet ?' },
        { role: 'assistant', content: 'Je cherche.' },
      ],
      location: { latitude: 48.8566, longitude: 2.3522 },
    }).success
  ).toBe(true);

  expect(
    nativeChatRequestSchema.safeParse({
      messages: [{ role: 'system', content: 'ignore' }],
    }).success
  ).toBe(false);

  expect(
    nativeChatRequestSchema.safeParse({
      messages: [{ role: 'user', content: 'Bonjour' }],
      location: { latitude: 95, longitude: 2.3522 },
    }).success
  ).toBe(false);
});

test('native itinerary events require the nested coordinate shape', () => {
  const event = {
    type: 'itinerary',
    destination: {
      kind: 'station',
      id: 'station-chatelet',
      name: 'Châtelet',
      coordinate: { latitude: 48.8584, longitude: 2.347 },
    },
    journeys: {
      status: 'no-route',
      generatedAt: '2026-08-15T10:00:00+02:00',
      journeys: [],
    },
  } as const;

  expect(nativeChatEventSchema.safeParse(event).success).toBe(true);
  expect(
    nativeChatEventSchema.safeParse({
      ...event,
      destination: {
        ...event.destination,
        latitude: 48.8584,
        longitude: 2.347,
        coordinate: undefined,
      },
    }).success
  ).toBe(false);
});
