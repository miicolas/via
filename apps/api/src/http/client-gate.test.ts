import { describe, expect, test } from 'bun:test';
import { Hono } from 'hono';

import type { AppEnv } from './app-env';
import { CLIENT_KEY_HEADER, clientCors, createClientGate } from './client-gate';

const APP_KEY = 'app-key-at-least-16-characters';
const SITE = 'https://metyro.app';

function gated(options: Parameters<typeof createClientGate>[0]) {
  const app = new Hono<AppEnv>();
  app.use('*', createClientGate(options));
  app.all('*', (c) => c.text('reached'));
  return app;
}

describe('client gate', () => {
  test('refuses a caller that presents no key', async () => {
    const app = gated({ label: 'app', keys: [APP_KEY] });

    const response = await app.request('/api/departures');

    expect(response.status).toBe(403);
    expect(await response.json()).toMatchObject({ error: { code: 'unknown_client' } });
  });

  test('accepts the shipped key and refuses a wrong one of the same length', async () => {
    const app = gated({ label: 'app', keys: [APP_KEY] });

    const accepted = await app.request('/api/departures', {
      headers: { [CLIENT_KEY_HEADER]: APP_KEY },
    });
    const refused = await app.request('/api/departures', {
      headers: { [CLIENT_KEY_HEADER]: 'xpp-key-at-least-16-characters' },
    });

    expect(accepted.status).toBe(200);
    expect(refused.status).toBe(403);
  });

  test('keeps a rotated-out key working while the previous build is on devices', async () => {
    const previous = 'previous-key-16-characters';
    const app = gated({ label: 'app', keys: [APP_KEY, previous] });

    const response = await app.request('/api/departures', {
      headers: { [CLIENT_KEY_HEADER]: previous },
    });

    expect(response.status).toBe(200);
  });

  test('answers the health probe without a key, and nothing else', async () => {
    const app = gated({ label: 'app', keys: [APP_KEY], exempt: ['/api/health'] });

    expect((await app.request('/api/health')).status).toBe(200);
    expect((await app.request('/api/health/detail')).status).toBe(403);
  });

  test('lets the site through on its origin, and no other origin', async () => {
    const app = gated({ label: 'site', keys: [], origins: [SITE] });

    const site = await app.request('/public/city-demand', {
      method: 'POST',
      headers: { origin: SITE },
    });
    const elsewhere = await app.request('/public/city-demand', {
      method: 'POST',
      headers: { origin: 'https://not-metyro.example' },
    });

    expect(site.status).toBe(200);
    expect(elsewhere.status).toBe(403);
  });

  test('lets the site render server-side, where a browser origin does not exist', async () => {
    const siteKey = 'site-key-at-least-16-characters';
    const app = gated({ label: 'site', keys: [siteKey], origins: [SITE] });

    const rendered = await app.request('/public/city-demand', {
      headers: { [CLIENT_KEY_HEADER]: siteKey },
    });
    const stranger = await app.request('/public/city-demand');

    expect(rendered.status).toBe(200);
    expect(stranger.status).toBe(403);
  });

  test('stays open while nothing is configured, so an empty .env still runs', async () => {
    const app = gated({ label: 'app', keys: [] });

    expect((await app.request('/api/departures')).status).toBe(200);
  });
});

describe('client CORS', () => {
  test('reflects the configured origin and refuses every other one', async () => {
    const app = new Hono<AppEnv>();
    app.use('*', clientCors([SITE]));
    app.get('*', (c) => c.text('reached'));

    const allowed = await app.request('/public/city-demand', { headers: { origin: SITE } });
    const refused = await app.request('/public/city-demand', {
      headers: { origin: 'https://not-metyro.example' },
    });

    expect(allowed.headers.get('access-control-allow-origin')).toBe(SITE);
    expect(refused.headers.get('access-control-allow-origin')).toBeNull();
  });

  test('advertises the client key header to preflights', async () => {
    const app = new Hono<AppEnv>();
    app.use('*', clientCors([SITE]));
    app.post('*', (c) => c.text('reached'));

    const preflight = await app.request('/public/city-demand', {
      method: 'OPTIONS',
      headers: {
        origin: SITE,
        'access-control-request-method': 'POST',
        'access-control-request-headers': CLIENT_KEY_HEADER,
      },
    });

    expect(preflight.headers.get('access-control-allow-headers')).toContain(CLIENT_KEY_HEADER);
  });
});
