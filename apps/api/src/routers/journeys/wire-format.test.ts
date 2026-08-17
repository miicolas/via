import { expect, test } from 'bun:test';

import { OpenAPIHandler } from '@orpc/openapi/fetch';
import { implement } from '@orpc/server';
import { experimental_ZodSmartCoercionPlugin as ZodSmartCoercionPlugin } from '@orpc/zod/zod4';
import { contract, type JourneyInput } from '@via/contract';

/**
 * GET /journeys carries a flattened destination and CSV mode lists because
 * deepObject query serialization cannot express nested objects or arrays —
 * the iOS client rejects them before the request leaves the device. These
 * tests pin the wire format by driving the same OpenAPIHandler production
 * uses with the exact query strings that client emits.
 */
function planEcho() {
  let received: JourneyInput | undefined;
  const plan = implement(contract.journeys.plan).handler(({ input }) => {
    received = input;
    return {
      status: 'no-route' as const,
      generatedAt: '2026-08-17T10:00:00.000Z',
      journeys: [],
    };
  });
  const handler = new OpenAPIHandler(
    { journeys: { plan } },
    { plugins: [new ZodSmartCoercionPlugin()] }
  );
  return {
    request: async (query: string) => {
      const { response } = await handler.handle(
        new Request(`https://api.test/journeys?${query}`),
        { context: {} }
      );
      return { status: response?.status, input: received };
    },
  };
}

test('a flattened station destination parses into the nested domain shape', async () => {
  const { status, input } = await planEcho().request(
    'origin[latitude]=48.881&origin[longitude]=2.155' +
      '&destination[kind]=station&destination[id]=IDFM%3A71379' +
      '&destination[name]=Chatou%20-%20Croissy' +
      '&destination[latitude]=48.8817&destination[longitude]=2.1557&limit=4'
  );

  expect(status).toBe(200);
  expect(input?.destination).toEqual({
    kind: 'station',
    id: 'IDFM:71379',
    name: 'Chatou - Croissy',
    coordinate: { latitude: 48.8817, longitude: 2.1557 },
  });
});

test('a flattened address destination keeps its context', async () => {
  const { status, input } = await planEcho().request(
    'origin[latitude]=48.881&origin[longitude]=2.155' +
      '&destination[kind]=address&destination[id]=ban%3A78146' +
      '&destination[name]=12%20rue%20des%20Cerisiers&destination[context]=Chatou' +
      '&destination[latitude]=48.89&destination[longitude]=2.15'
  );

  expect(status).toBe(200);
  expect(input?.destination).toEqual({
    kind: 'address',
    id: 'ban:78146',
    name: '12 rue des Cerisiers',
    context: 'Chatou',
    coordinate: { latitude: 48.89, longitude: 2.15 },
  });
});

test('CSV mode lists parse into arrays', async () => {
  const { status, input } = await planEcho().request(
    'origin[latitude]=48.881&origin[longitude]=2.155' +
      '&destination[kind]=station&destination[id]=IDFM%3A71379' +
      '&destination[name]=Chatou%20-%20Croissy' +
      '&destination[latitude]=48.8817&destination[longitude]=2.1557' +
      '&preferredModes=metro,rer&excludedModes=bus'
  );

  expect(status).toBe(200);
  expect(input?.preferredModes).toEqual(['metro', 'rer']);
  expect(input?.excludedModes).toEqual(['bus']);
  expect(input?.requiredModes).toBeUndefined();
});

test('an unknown mode in the CSV is rejected', async () => {
  const { status } = await planEcho().request(
    'origin[latitude]=48.881&origin[longitude]=2.155' +
      '&destination[kind]=station&destination[id]=IDFM%3A71379' +
      '&destination[name]=Chatou%20-%20Croissy' +
      '&destination[latitude]=48.8817&destination[longitude]=2.1557' +
      '&preferredModes=hovercraft'
  );

  expect(status).toBe(400);
});
