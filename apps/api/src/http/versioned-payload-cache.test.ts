import { expect, test } from 'bun:test';
import { Hono } from 'hono';
import { compress } from 'hono/compress';
import { etag } from 'hono/etag';

import type { AppEnv } from './app-env';
import { versionedPayloadCache } from './versioned-payload-cache';

const PAYLOAD = { hello: 'réseau'.repeat(400) };

/**
 * The middleware only behaves correctly in the sandwich it is mounted in, so
 * the harness reproduces it: `compress()` outside, `etag()` inside, exactly as
 * `app.ts` wires them.
 */
function harness(version: () => Promise<string>) {
  let handlerCalls = 0;
  const app = new Hono<AppEnv>();
  app.use('*', compress());
  app.use('*', versionedPayloadCache(version));
  app.use('*', etag());
  app.get('/payload', (c) => {
    handlerCalls += 1;
    c.header('Cache-Control', 'private, max-age=86400');
    return c.json(PAYLOAD);
  });
  return { app, calls: () => handlerCalls };
}

const gzipRequest = (url = 'http://x/payload', headers: Record<string, string> = {}) =>
  new Request(url, { headers: { 'Accept-Encoding': 'gzip', ...headers } });

/**
 * `app.request()` hands back the raw Response; unlike an HTTP client, nothing
 * in between honours `Content-Encoding`. So the test decodes it the way the
 * network would.
 */
async function decode(response: Response) {
  if (response.headers.get('Content-Encoding') !== 'gzip') return response.json();
  const bytes = await response.arrayBuffer();
  const stream = new Response(bytes).body!.pipeThrough(new DecompressionStream('gzip'));
  return new Response(stream).json();
}

test('a second request is served from memory, gzipped, without running the handler', async () => {
  const { app, calls } = harness(async () => 'v1');

  const first = await app.request(gzipRequest());
  const second = await app.request(gzipRequest());

  expect(first.status).toBe(200);
  expect(second.status).toBe(200);
  expect(calls()).toBe(1);
  expect(second.headers.get('Content-Encoding')).toBe('gzip');
  // Same bytes, and the tag is the weak form `compress()` would have produced.
  expect(second.headers.get('ETag')).toBe(first.headers.get('ETag'));
  expect(second.headers.get('ETag')).toStartWith('W/"');
  expect(await decode(second)).toEqual(PAYLOAD);
});

test('the cached body decodes to exactly what the handler returned', async () => {
  const { app } = harness(async () => 'v1');

  await app.request(gzipRequest());
  const cached = await app.request(gzipRequest());

  expect(await decode(cached)).toEqual(PAYLOAD);
});

test('a matching If-None-Match gets a 304 that keeps its validators', async () => {
  const { app, calls } = harness(async () => 'v1');

  const first = await app.request(gzipRequest());
  const tag = first.headers.get('ETag') ?? '';
  const revalidated = await app.request(gzipRequest('http://x/payload', { 'If-None-Match': tag }));

  expect(revalidated.status).toBe(304);
  expect(revalidated.headers.get('ETag')).toBe(tag);
  expect(revalidated.headers.get('Cache-Control')).toBe('private, max-age=86400');
  expect(await revalidated.text()).toBe('');
  expect(calls()).toBe(1);
});

test('a strong If-None-Match still matches the weak tag it was derived from', async () => {
  const { app } = harness(async () => 'v1');

  const first = await app.request(gzipRequest());
  const strong = (first.headers.get('ETag') ?? '').replace(/^W\//, '');
  const revalidated = await app.request(
    gzipRequest('http://x/payload', { 'If-None-Match': strong })
  );

  expect(revalidated.status).toBe(304);
});

test('a new network version invalidates the entry', async () => {
  let version = 'v1';
  const { app, calls } = harness(async () => version);

  await app.request(gzipRequest());
  await app.request(gzipRequest());
  expect(calls()).toBe(1);

  version = 'v2';
  await app.request(gzipRequest());
  expect(calls()).toBe(2);
});

test('a client that cannot take gzip falls through to the uncompressed path', async () => {
  const { app } = harness(async () => 'v1');

  await app.request(gzipRequest());
  const plain = await app.request(
    new Request('http://x/payload', { headers: { 'Accept-Encoding': 'identity' } })
  );

  expect(plain.status).toBe(200);
  expect(plain.headers.get('Content-Encoding')).toBeNull();
  expect(await decode(plain)).toEqual(PAYLOAD);
});

test('a failing handler is neither served nor remembered', async () => {
  let fail = true;
  const app = new Hono<AppEnv>();
  app.use('*', compress());
  app.use('*', versionedPayloadCache(async () => 'v1'));
  app.use('*', etag());
  app.get('/payload', (c) => (fail ? c.json({ error: true }, 503) : c.json(PAYLOAD)));

  const failed = await app.request(gzipRequest());
  expect(failed.status).toBe(503);

  fail = false;
  const recovered = await app.request(gzipRequest());
  expect(recovered.status).toBe(200);
  expect(await decode(recovered)).toEqual(PAYLOAD);
});
