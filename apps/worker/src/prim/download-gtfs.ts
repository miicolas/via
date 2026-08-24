import { createWriteStream } from 'node:fs';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';

const PRIM_GTFS_RECORDS_URL =
  'https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/' +
  'offre-horaires-tc-gtfs-idfm/records?limit=1';

const TRUSTED_DOWNLOAD_HOSTS = new Set([
  'data.iledefrance-mobilites.fr',
  'eu.ftp.opendatasoft.com',
]);

export type HttpValidators = {
  etag?: string;
  lastModified?: string;
};

export type PrimGtfsDownloadResult =
  | { status: 'unchanged' }
  | { status: 'downloaded'; validators: HttpValidators };

type Fetcher = (
  input: string | URL | Request,
  init?: RequestInit
) => Promise<Response>;

type DownloadOptions = {
  token: string;
  destination: string;
  validators: HttpValidators;
  fetcher?: Fetcher;
};

function recordDownloadUrl(payload: unknown): URL {
  if (!payload || typeof payload !== 'object') {
    throw new Error('PRIM GTFS dataset returned an invalid response');
  }
  const results = (payload as { results?: unknown }).results;
  if (!Array.isArray(results) || results.length !== 1) {
    throw new Error('PRIM GTFS dataset did not return exactly one archive');
  }
  const record = results[0];
  if (!record || typeof record !== 'object') {
    throw new Error('PRIM GTFS dataset returned an invalid archive record');
  }
  const file = (record as { url?: unknown }).url;
  const value =
    typeof file === 'string'
      ? file
      : file && typeof file === 'object' && typeof (file as { url?: unknown }).url === 'string'
        ? (file as { url: string }).url
        : undefined;
  if (!value) throw new Error('PRIM GTFS dataset archive has no download URL');

  const url = new URL(value);
  if (url.protocol !== 'https:' || !TRUSTED_DOWNLOAD_HOSTS.has(url.hostname)) {
    throw new Error(`PRIM returned an untrusted GTFS download host: ${url.hostname}`);
  }
  return url;
}

function responseValidators(response: Response): HttpValidators {
  const etag = response.headers.get('ETag') ?? undefined;
  const lastModified = response.headers.get('Last-Modified') ?? undefined;
  return { etag, lastModified };
}

export async function downloadPrimGtfsSnapshot({
  token,
  destination,
  validators,
  fetcher = fetch,
}: DownloadOptions): Promise<PrimGtfsDownloadResult> {
  const authorization = `apikey ${token}`;
  const datasetResponse = await fetcher(PRIM_GTFS_RECORDS_URL, {
    headers: { Authorization: authorization },
    signal: AbortSignal.timeout(30_000),
  });
  if (!datasetResponse.ok) {
    throw new Error(`PRIM GTFS dataset request failed with HTTP ${datasetResponse.status}`);
  }

  const downloadUrl = recordDownloadUrl(await datasetResponse.json());
  const headers = new Headers();
  if (downloadUrl.hostname === 'data.iledefrance-mobilites.fr') {
    headers.set('Authorization', authorization);
  }
  if (validators.etag) headers.set('If-None-Match', validators.etag);
  if (validators.lastModified) headers.set('If-Modified-Since', validators.lastModified);

  const archiveResponse = await fetcher(downloadUrl, {
    headers,
    signal: AbortSignal.timeout(10 * 60_000),
  });
  if (archiveResponse.status === 304) return { status: 'unchanged' };
  if (!archiveResponse.ok) {
    throw new Error(`PRIM GTFS archive download failed with HTTP ${archiveResponse.status}`);
  }
  if (!archiveResponse.body) throw new Error('PRIM GTFS archive response has no body');

  await pipeline(
    Readable.fromWeb(archiveResponse.body as ReadableStream<Uint8Array>),
    createWriteStream(destination)
  );
  return { status: 'downloaded', validators: responseValidators(archiveResponse) };
}
