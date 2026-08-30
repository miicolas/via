export type PrimProduct =
  | 'disruptions_bulk'
  | 'stop_monitoring'
  | 'journey_planner';

export type PrimRequestEvent = {
  level: 'info' | 'error';
  provider: 'prim';
  product: PrimProduct;
  outcome:
    | 'success'
    | 'http_error'
    | 'timeout'
    | 'aborted'
    | 'network_error'
    | 'invalid_json';
  durationMs: number;
  httpStatus?: number;
};

type PrimTelemetry = {
  provider: 'prim';
  product: PrimProduct;
  record?: (event: PrimRequestEvent) => void;
};

type JsonFetcher = (url: URL, init?: RequestInit) => Promise<Response>;

type FetchJsonOptions = {
  headers?: Record<string, string>;
  /** Cancels with the request; composed with the timeout. */
  signal?: AbortSignal;
  timeoutMs: number;
  /** Names non-PRIM upstreams in their legacy failure log. */
  logLabel: string;
  telemetry?: PrimTelemetry;
  /** Injectable transport for tests at the HTTP boundary. */
  fetcher?: JsonFetcher;
  /** Injectable sink for non-PRIM upstream events. */
  recorder?: (event: UpstreamRequestEvent) => void;
};

export type UpstreamRequestEvent = {
  readonly event: 'upstream_request';
  readonly logLabel: string;
  readonly outcome:
    | 'http_error'
    | 'timeout'
    | 'aborted'
    | 'network_error'
    | 'invalid_json';
  readonly durationMs: number;
  readonly httpStatus?: number;
};

/** Every way the round-trip can fail, in the telemetry's own vocabulary. */
export type JsonFetchFailure = Exclude<PrimRequestEvent['outcome'], 'success'>;

export type JsonFetchResult =
  | { outcome: 'success'; body: unknown }
  | { outcome: JsonFetchFailure };

/**
 * One JSON round-trip to an upstream the API must survive losing. Never
 * throws — an upstream outage must degrade the response, not turn it into a
 * 500. `null` means "the upstream did not answer"; the caller decides what
 * that costs.
 */
export async function fetchJsonOrNull(
  url: URL,
  options: FetchJsonOptions,
): Promise<unknown | null> {
  const result = await fetchJsonResult(url, options);
  return result.outcome === 'success' ? result.body : null;
}

/**
 * The same round-trip for a caller whose fallback policy depends on *why* the
 * upstream did not answer — a timeout and a 401 do not deserve the same retry.
 */
export async function fetchJsonResult(
  url: URL,
  {
    headers,
    signal,
    timeoutMs,
    logLabel,
    telemetry,
    fetcher = fetch,
    recorder,
  }: FetchJsonOptions,
): Promise<JsonFetchResult> {
  const timeout = AbortSignal.timeout(timeoutMs);
  const startedAt = performance.now();
  let httpStatus: number | undefined;

  const failure = (outcome: JsonFetchFailure): JsonFetchResult => {
    const measured = {
      outcome,
      durationMs: elapsedMs(startedAt),
      ...(httpStatus === undefined ? {} : { httpStatus }),
    };
    if (telemetry) {
      recordTelemetry(telemetry, { level: 'error', ...measured });
    } else {
      recordUpstream(recorder, { event: 'upstream_request', logLabel, ...measured });
    }
    return { outcome };
  };

  try {
    const response = await fetcher(url, {
      headers,
      signal: signal ? AbortSignal.any([timeout, signal]) : timeout,
    });
    httpStatus = response.status;

    if (!response.ok) return failure('http_error');

    try {
      const body: unknown = await response.json();
      recordTelemetry(telemetry, {
        level: 'info',
        outcome: 'success',
        durationMs: elapsedMs(startedAt),
        httpStatus,
      });
      return { outcome: 'success', body };
    } catch (cause) {
      return failure('invalid_json');
    }
  } catch (cause) {
    return failure(
      signal?.aborted ? 'aborted' : timeout.aborted ? 'timeout' : 'network_error'
    );
  }
}

function recordTelemetry(
  telemetry: PrimTelemetry | undefined,
  event: Omit<PrimRequestEvent, 'provider' | 'product'>,
) {
  if (!telemetry) return;
  const completed: PrimRequestEvent = {
    ...event,
    provider: telemetry.provider,
    product: telemetry.product,
  };

  try {
    (telemetry.record ?? writeStructuredLog)(completed);
  } catch {
    // Observability must never change the upstream fallback semantics.
  }
}

function writeStructuredLog(event: PrimRequestEvent) {
  console.log(JSON.stringify(event));
}

function recordUpstream(recorder: ((event: UpstreamRequestEvent) => void) | undefined, event: UpstreamRequestEvent) {
  try {
    (recorder ?? writeUpstreamLog)(event);
  } catch {
    // Observability must never change the upstream fallback semantics.
  }
}

function writeUpstreamLog(event: UpstreamRequestEvent) {
  console.log(JSON.stringify(event));
}

function elapsedMs(startedAt: number) {
  return Math.max(0, Math.round(performance.now() - startedAt));
}
