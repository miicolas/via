import type { Context, MiddlewareHandler, Next } from 'hono';

import type { AppEnv } from './app-env';

/**
 * Headers that describe the payload rather than the request that fetched it.
 * `x-request-id` is deliberately absent: replaying a cached one would label two
 * different requests with the same id in the logs.
 */
const PAYLOAD_HEADERS = ['content-type', 'cache-control', 'vary'];

/** What hono's own `etag()` keeps on a 304, so a cached one looks identical. */
const RETAINED_304_HEADERS = ['cache-control', 'etag', 'vary'];

type CachedPayload = {
  version: string;
  etag: string;
  gzip: ArrayBuffer;
  headers: [string, string][];
};

/**
 * Serves a whole response — gzipped bytes, ETag and all — from memory for
 * payloads that only change when a GTFS import runs.
 *
 * The rail map is 1.14 MB of JSON. `getRailMap` already memoizes the assembled
 * object, but the memo only saves the two database reads: oRPC still revalidates
 * that object against `railMapSchema` on every request (zod rebuilds the entire
 * graph to hand back `result.value`), `JSON.stringify` still walks it, `etag()`
 * still hashes 1.17 MB and `compress()` still gzips it. Measured on the real
 * payload that is 14.3 + 8.9 + ~3 + 17.2 ms of CPU and roughly 4 MB of garbage
 * per request, for bytes that were already identical.
 *
 * Placement is what makes this cheap rather than duplicated work. Mounted
 * between `compress()` and `etag()`, the miss path still goes through both the
 * handler and hono's digest, so the cached ETag is the one hono itself
 * produced — no need to reimplement its chunk-chained SHA-1. On the way out
 * this middleware gzips once and stamps `Content-Encoding`, which makes the
 * outer `compress()` skip the response it would otherwise have compressed
 * again. On a hit nothing downstream runs at all.
 *
 * Only responses to clients that accept gzip are served from the cache; anyone
 * else falls through to the normal path and gets identical bytes uncompressed.
 */
export function versionedPayloadCache(readVersion: () => Promise<string>): MiddlewareHandler<AppEnv> {
  const byPath = new Map<string, CachedPayload>();

  return async function cachePayload(c: Context<AppEnv>, next: Next) {
    if (c.req.method !== 'GET' || !acceptsGzip(c)) {
      await next();
      return;
    }

    const version = await readVersion();
    const cached = byPath.get(c.req.path);

    if (cached?.version === version) {
      serve(c, cached);
      return;
    }

    await next();

    // Anything but a plain 200 — an error, a 304 from a conditional request
    // that raced the version change — is passed through and not remembered.
    if (c.res.status !== 200) return;
    const etag = c.res.headers.get('ETag');
    if (!etag) return;

    const headers = [...c.res.headers.entries()].filter(([name]) =>
      PAYLOAD_HEADERS.includes(name.toLowerCase())
    );
    const body = new Uint8Array(await c.res.arrayBuffer());
    const fresh: CachedPayload = {
      version,
      // `compress()` weakens the tag when it encodes a body; do the same here,
      // because from here on this middleware is what encodes it.
      etag: etag.startsWith('W/') ? etag : `W/${etag}`,
      gzip: await gzip(body),
      headers,
    };
    byPath.set(c.req.path, fresh);

    serve(c, fresh);
  };
}

/**
 * Installs the cached payload as the response.
 *
 * Assignment rather than `return`: hono's `compose` only adopts a value a
 * middleware returns while `context.finalized` is false, and the moment the
 * handler downstream produced a response it is true — a returned `Response`
 * from here would be dropped on the floor without a word.
 *
 * Hono's setter then copies the previous response's headers onto this one,
 * which is how `x-request-id` and CORS survive but also how the uncompressed
 * body's `ETag` and `Content-Length` would come back on top of a gzipped body.
 * So the two that describe the encoding are re-stamped afterwards rather than
 * clearing `c.res` first, which would take the request id with it.
 */
function serve(c: Context<AppEnv>, payload: CachedPayload) {
  const headers = new Headers(payload.headers);
  headers.set('ETag', payload.etag);

  if (isNotModified(c.req.header('If-None-Match'), payload.etag)) {
    // The 304 answers a request that negotiated an encoding, so it carries the
    // same `Vary` as the 200 it stands in for.
    appendVaryAcceptEncoding(headers);
    for (const name of [...headers.keys()]) {
      if (!RETAINED_304_HEADERS.includes(name.toLowerCase())) headers.delete(name);
    }
    c.res = new Response(null, { status: 304, headers });
    for (const name of [...c.res.headers.keys()]) {
      if (!RETAINED_304_HEADERS.includes(name.toLowerCase())) c.res.headers.delete(name);
    }
    c.res.headers.set('ETag', payload.etag);
    return;
  }

  headers.set('Content-Encoding', 'gzip');
  appendVaryAcceptEncoding(headers);
  c.res = new Response(payload.gzip, { status: 200, headers });
  c.res.headers.set('ETag', payload.etag);
  c.res.headers.set('Content-Encoding', 'gzip');
  c.res.headers.delete('Content-Length');
}

/** `W/"x"` and `"x"` are the same entity to a conditional request. */
function isNotModified(ifNoneMatch: string | undefined, etag: string) {
  if (!ifNoneMatch) return false;
  if (ifNoneMatch === '*') return true;
  const strip = (tag: string) => tag.trim().replace(/^W\//, '');
  return ifNoneMatch.split(',').some((candidate) => strip(candidate) === strip(etag));
}

function acceptsGzip(c: Context<AppEnv>) {
  return /(^|,)\s*(gzip|\*)\s*(;|,|$)/.test(c.req.header('Accept-Encoding') ?? '');
}

function appendVaryAcceptEncoding(headers: Headers) {
  const current = headers.get('Vary');
  if (current === '*') return;
  if (current && /(?:^|,)\s*accept-encoding\s*(?:,|$)/i.test(current)) return;
  headers.set('Vary', current ? `${current}, Accept-Encoding` : 'Accept-Encoding');
}

async function gzip(body: Uint8Array<ArrayBuffer>): Promise<ArrayBuffer> {
  const stream = new CompressionStream('gzip');
  const writer = stream.writable.getWriter();
  void writer.write(body);
  void writer.close();
  return await new Response(stream.readable).arrayBuffer();
}
