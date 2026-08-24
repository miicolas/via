import { expect, test } from 'bun:test';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

import { downloadPrimGtfsSnapshot } from './download-gtfs';

test('downloads the authenticated PRIM GTFS conditionally without exposing the token', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'via-prim-download-test-'));
  const destination = join(directory, 'snapshot.zip');
  const requests: Array<{ url: string; headers: Headers }> = [];
  const responses = [
    Response.json({
      results: [
        {
          filename: 'IDFM-gtfs.zip',
          url: {
            filename: 'IDFM-gtfs.zip',
            mimetype: 'application/zip',
            url: 'https://data.iledefrance-mobilites.fr/files/current-gtfs',
          },
        },
      ],
    }),
    new Response('zip-bytes', {
      status: 200,
      headers: {
        ETag: '"feed-42"',
        'Last-Modified': 'Mon, 24 Aug 2026 06:00:10 GMT',
      },
    }),
  ];

  try {
    const result = await downloadPrimGtfsSnapshot({
      token: 'secret-dataset-token',
      destination,
      validators: {
        etag: '"feed-41"',
        lastModified: 'Sun, 23 Aug 2026 06:00:10 GMT',
      },
      fetcher: async (input, init) => {
        requests.push({ url: String(input), headers: new Headers(init?.headers) });
        return responses.shift()!;
      },
    });

    expect(result).toEqual({
      status: 'downloaded',
      validators: {
        etag: '"feed-42"',
        lastModified: 'Mon, 24 Aug 2026 06:00:10 GMT',
      },
    });
    expect(await readFile(destination, 'utf8')).toBe('zip-bytes');
    expect(requests).toHaveLength(2);
    expect(requests[0]!.headers.get('Authorization')).toBe('apikey secret-dataset-token');
    expect(requests[1]!.headers.get('Authorization')).toBe('apikey secret-dataset-token');
    expect(requests[1]!.headers.get('If-None-Match')).toBe('"feed-41"');
    expect(requests[1]!.headers.get('If-Modified-Since')).toBe(
      'Sun, 23 Aug 2026 06:00:10 GMT'
    );
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('returns unchanged when the PRIM archive answers 304', async () => {
  const responses = [
    Response.json({ results: [{ url: 'https://eu.ftp.opendatasoft.com/stif/GTFS/IDFM-gtfs.zip' }] }),
    new Response(null, { status: 304 }),
  ];

  const result = await downloadPrimGtfsSnapshot({
    token: 'secret-dataset-token',
    destination: '/unused/snapshot.zip',
    validators: { etag: '"same-feed"' },
    fetcher: async () => responses.shift()!,
  });

  expect(result).toEqual({ status: 'unchanged' });
});

test('rejects a download URL outside the official trusted hosts', async () => {
  await expect(
    downloadPrimGtfsSnapshot({
      token: 'secret-dataset-token',
      destination: '/unused/snapshot.zip',
      validators: {},
      fetcher: async () =>
        Response.json({ results: [{ url: { url: 'https://example.com/forged.zip' } }] }),
    })
  ).rejects.toThrow('untrusted GTFS download host');
});

test('fails explicitly when the authenticated PRIM dataset request is refused', async () => {
  await expect(
    downloadPrimGtfsSnapshot({
      token: 'rejected-token',
      destination: '/unused/snapshot.zip',
      validators: {},
      fetcher: async () => new Response('{"error":"forbidden"}', { status: 403 }),
    })
  ).rejects.toThrow('PRIM GTFS dataset request failed with HTTP 403');
});
