import { describe, expect, test } from 'bun:test';
import { Hono } from 'hono';
import { requestId } from 'hono/request-id';

import type { AppEnv } from './app-env';
import { requestBodyLimit, MAX_REQUEST_BODY_BYTES } from './request-body-limit';

function testApp() {
  const app = new Hono<AppEnv>();
  let handlerCalls = 0;
  app.use(requestId());
  app.post('/payload', requestBodyLimit, async (c) => {
    handlerCalls += 1;
    await c.req.arrayBuffer();
    return c.json({ ok: true });
  });
  return { app, calls: () => handlerCalls };
}

function responseBody(response: Response) {
  return response.json() as Promise<{ error?: { code?: string; requestId?: string } }>;
}

function streamBody(size: number, chunkSize = 64 * 1024) {
  let remaining = size;
  return new ReadableStream<Uint8Array>({
    pull(controller) {
      if (remaining <= 0) {
        controller.close();
        return;
      }
      const chunk = new Uint8Array(Math.min(chunkSize, remaining));
      remaining -= chunk.byteLength;
      controller.enqueue(chunk);
    },
  });
}

describe('request body limit', () => {
  test('allows a declared body exactly at 1 MiB', async () => {
    const { app, calls } = testApp();
    const response = await app.request('/payload', {
      method: 'POST',
      headers: { 'content-length': String(MAX_REQUEST_BODY_BYTES) },
      body: new Uint8Array(MAX_REQUEST_BODY_BYTES),
    });

    expect(response.status).toBe(200);
    expect(calls()).toBe(1);
  });

  test('rejects a declared body above 1 MiB before the handler', async () => {
    const { app, calls } = testApp();
    const response = await app.request('/payload', {
      method: 'POST',
      headers: { 'content-length': String(MAX_REQUEST_BODY_BYTES + 1) },
      body: new Uint8Array(1),
    });
    const body = await responseBody(response);

    expect(response.status).toBe(413);
    expect(body.error?.code).toBe('payload_too_large');
    expect(body.error?.requestId).toBeString();
    expect(calls()).toBe(0);
  });

  test('allows a streamed body exactly at 1 MiB', async () => {
    const { app, calls } = testApp();
    const response = await app.request('/payload', {
      method: 'POST',
      body: streamBody(MAX_REQUEST_BODY_BYTES),
      // Bun requires duplex for a request backed by a ReadableStream.
      duplex: 'half',
    } as RequestInit & { duplex: 'half' });

    expect(response.status).toBe(200);
    expect(calls()).toBe(1);
  });

  test('rejects a streamed body above 1 MiB before the handler', async () => {
    const { app, calls } = testApp();
    const response = await app.request('/payload', {
      method: 'POST',
      body: streamBody(MAX_REQUEST_BODY_BYTES + 1),
      duplex: 'half',
    } as RequestInit & { duplex: 'half' });
    const body = await responseBody(response);

    expect(response.status).toBe(413);
    expect(body.error?.code).toBe('payload_too_large');
    expect(body.error?.requestId).toBeString();
    expect(calls()).toBe(0);
  });
});
