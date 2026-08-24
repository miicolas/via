import { expect, test } from 'bun:test';

import { OpenAPIHandler } from '@orpc/openapi/fetch';
import { implement } from '@orpc/server';
import { experimental_ZodSmartCoercionPlugin as ZodSmartCoercionPlugin } from '@orpc/zod/zod4';
import { contract } from '@via/contract';

/**
 * Swift's OpenAPI runtime serializes whole-number doubles as `"-122.0"`, and the
 * smart-coercion plugin leaves those strings alone (its `Number→String` round-trip
 * yields `"-122"`). The tiled station fetches put whole degrees on tile edges, so
 * the schemas coerce for themselves — this drives the failing production URL
 * through a stub handler wired exactly like `openApiHandler`.
 */
const stubStationsInArea = implement(contract.network.stationsInArea).handler(() => ({
  stations: [],
  routes: [],
  bikeStations: [],
  sources: { velib: 'ok' },
}));

const handler = new OpenAPIHandler(stubStationsInArea, {
  plugins: [new ZodSmartCoercionPlugin()],
});

test('stationsInArea accepts whole-degree bounds serialized with a trailing .0', async () => {
  const { matched, response } = await handler.handle(
    new Request(
      'http://api.test/network/stations?minLatitude=37.225&maxLatitude=37.25&minLongitude=-122.025&maxLongitude=-122.0'
    )
  );

  expect(matched).toBe(true);
  expect(response?.status).toBe(200);
  expect(await response?.json()).toEqual({
    stations: [],
    routes: [],
    bikeStations: [],
    sources: { velib: 'ok' },
  });
});

test('stationsInArea still rejects an oversized area', async () => {
  const { response } = await handler.handle(
    new Request(
      'http://api.test/network/stations?minLatitude=37.0&maxLatitude=37.1&minLongitude=-122.1&maxLongitude=-122.0'
    )
  );

  expect(response?.status).toBe(400);
});
