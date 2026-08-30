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
    'GET /api/friends',
    'GET /api/friends/invitations/preview',
    'GET /api/health',
    'GET /api/journeys',
    'GET /api/journeys/shares',
    'GET /api/lines/detail',
    'GET /api/lines/search',
    'GET /api/lines/statuses',
    'GET /api/meetups',
    'GET /api/meetups/detail',
    'GET /api/meetups/invitations/preview',
    'GET /api/meetups/keys',
    'GET /api/meetups/live',
    'GET /api/network/bike-stations',
    'GET /api/network/rail-map',
    'GET /api/network/shared-mobility',
    'GET /api/network/station-crowding',
    'GET /api/network/stations',
    'GET /api/notifications/inbox',
    'GET /api/reports/station-status',
    'GET /api/search',
    'POST /api/account/delete',
    'POST /api/account/sync',
    'POST /api/friends/invitations',
    'POST /api/friends/invitations/accept',
    'POST /api/friends/remove',
    'POST /api/journeys/departure-choices',
    'POST /api/journeys/shares',
    'POST /api/meetups',
    'POST /api/meetups/cancel',
    'POST /api/meetups/invitations',
    'POST /api/meetups/invitations/accept',
    'POST /api/meetups/invitations/decline',
    'POST /api/meetups/invitations/revoke',
    'POST /api/meetups/keys/device',
    'POST /api/meetups/keys/envelopes',
    'POST /api/meetups/leave',
    'POST /api/meetups/live',
    'POST /api/meetups/live-activity',
    'POST /api/meetups/live-activity/unregister',
    'POST /api/meetups/participant',
    'POST /api/meetups/remove',
    'POST /api/meetups/update',
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
