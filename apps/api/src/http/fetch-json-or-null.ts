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
};

/**
 * One JSON round-trip to an upstream the API must survive losing. Never
 * throws — an upstream outage must degrade the response, not turn it into a
 * 500. `null` means "the upstream did not answer"; the caller decides what
 * that costs.
 */
export async function fetchJsonOrNull(
  url: URL,
  {
    headers,
    signal,
    timeoutMs,
    logLabel,
    telemetry,
    fetcher = fetch,
  }: FetchJsonOptions,
): Promise<unknown | null> {
  const timeout = AbortSignal.timeout(timeoutMs);
  const startedAt = performance.now();
  let httpStatus: number | undefined;

  try {
    const response = await fetcher(url, {
      headers,
      signal: signal ? AbortSignal.any([timeout, signal]) : timeout,
    });
    httpStatus = response.status;

    if (!response.ok) {
      if (telemetry) {
        recordTelemetry(telemetry, {
          level: 'error',
          outcome: 'http_error',
          durationMs: elapsedMs(startedAt),
          httpStatus,
        });
      } else {
        console.error(`${logLabel} indisponible (HTTP ${httpStatus})`);
      }
      return null;
    }

    try {
      const body: unknown = await response.json();
      recordTelemetry(telemetry, {
        level: 'info',
        outcome: 'success',
        durationMs: elapsedMs(startedAt),
        httpStatus,
      });
      return body;
    } catch (cause) {
      if (telemetry) {
        recordTelemetry(telemetry, {
          level: 'error',
          outcome: 'invalid_json',
          durationMs: elapsedMs(startedAt),
          httpStatus,
        });
      } else {
        console.error(`${logLabel} indisponible`, cause);
      }
      return null;
    }
  } catch (cause) {
    if (telemetry) {
      recordTelemetry(telemetry, {
        level: 'error',
        outcome: signal?.aborted
          ? 'aborted'
          : timeout.aborted
            ? 'timeout'
            : 'network_error',
        durationMs: elapsedMs(startedAt),
        ...(httpStatus === undefined ? {} : { httpStatus }),
      });
    } else {
      console.error(`${logLabel} indisponible`, cause);
    }
    return null;
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

function elapsedMs(startedAt: number) {
  return Math.max(0, Math.round(performance.now() - startedAt));
}
