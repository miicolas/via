import { expect, test } from 'bun:test';

import { getOpenApiDocument } from '../orpc/openapi';

type OpenApiDocument = {
  paths?: Record<string, Record<string, unknown>>;
};

/**
 * The public surface, asserted from the generated document rather than from the
 * Hono route table — under oRPC, Hono only sees one catch-all mount, so the real
 * paths live in the contract.
 *
 * It matters because clients address routes by URL: a moved path is a production
 * break, and generating the document also proves every zod schema in the contract
 * can be converted to JSON Schema.
 */
test('the public route table is stable', async () => {
  const { paths = {} } = (await getOpenApiDocument()) as OpenApiDocument;

  const routes = Object.entries(paths)
    .flatMap(([path, methods]) =>
      Object.keys(methods).map((method) => `${method.toUpperCase()} /api${path}`)
    )
    .sort();

  expect(routes).toEqual([
    'GET /api/departures',
    'GET /api/health',
    'GET /api/journeys',
    'GET /api/lines/detail',
    'GET /api/lines/search',
    'GET /api/lines/statuses',
    'GET /api/network/bike-stations',
    'GET /api/network/rail-map',
    'GET /api/network/stations',
    'GET /api/notifications/inbox',
    'GET /api/reports/station-status',
    'GET /api/search',
    'POST /api/account/delete',
    'POST /api/account/sync',
    'POST /api/journeys/departure-choices',
    'POST /api/natural-journeys',
    'POST /api/notifications/active-journey',
    'POST /api/notifications/active-journey/unregister',
    'POST /api/notifications/device',
    'POST /api/notifications/device/unregister',
    'POST /api/notifications/inbox/read',
    'POST /api/notifications/live-activity',
    'POST /api/notifications/live-activity/push-to-start',
    'POST /api/notifications/live-activity/unregister',
    'POST /api/notifications/mute',
    'POST /api/notifications/snooze',
    'POST /api/reports',
  ]);
});
