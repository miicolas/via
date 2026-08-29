import { expect, test } from 'bun:test';
import { Hono } from 'hono';
import { requestId } from 'hono/request-id';

import type { AppEnv } from './app-env';
import { requestLogger, type RequestLogEvent } from './request-logger';

function loggedApp(events: RequestLogEvent[]) {
  const app = new Hono<AppEnv>();
  app.use(requestId());
  app.use(requestLogger((event) => events.push(event)));
  app.get('/public/journey-shares/:token', (c) => c.json({ ok: true }));
  app.get('/public/rejected/:token', (c) => c.json({ ok: false }, 429));
  return app;
}

test('emits one bounded event with the registered route pattern', async () => {
  const events: RequestLogEvent[] = [];
  const app = loggedApp(events);
  const response = await app.request(
    '/public/journey-shares/private-token?search=private-street&latitude=48.8566&longitude=2.3522',
    {
      headers: {
        'x-private-header': 'private-header-value',
      },
    },
  );

  expect(response.status).toBe(200);
  expect(events).toHaveLength(1);
  expect(events[0]).toMatchObject({
    event: 'http_request',
    method: 'GET',
    route: '/public/journey-shares/:token',
    status: 200,
  });
  expect(events[0]?.requestId).toBeString();
  expect(events[0]?.durationMs).toBeGreaterThanOrEqual(0);
  const serialized = JSON.stringify(events[0]);
  expect(serialized).not.toContain('private-token');
  expect(serialized).not.toContain('private-street');
  expect(serialized).not.toContain('48.8566');
  expect(serialized).not.toContain('2.3522');
  expect(serialized).not.toContain('private-header-value');
});

test('emits the same closed shape for a client error', async () => {
  const events: RequestLogEvent[] = [];
  const app = loggedApp(events);
  const response = await app.request('/public/rejected/private-token');

  expect(response.status).toBe(429);
  expect(events).toHaveLength(1);
  expect(events[0]).toMatchObject({
    event: 'http_request',
    method: 'GET',
    route: '/public/rejected/:token',
    status: 429,
  });
  expect(JSON.stringify(events[0])).not.toContain('private-token');
});

test('a failing sink never changes the response', async () => {
  const app = new Hono<AppEnv>();
  app.use(requestId());
  app.use(requestLogger(() => {
    throw new Error('sink failure');
  }));
  app.get('/public/ok', (c) => c.text('ok'));

  const response = await app.request('/public/ok');

  expect(response.status).toBe(200);
  expect(await response.text()).toBe('ok');
});
