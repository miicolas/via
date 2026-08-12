type FetchJsonOptions = {
  headers?: Record<string, string>;
  /** Cancels with the request; composed with the timeout. */
  signal?: AbortSignal;
  timeoutMs: number;
  /** Names the upstream in the failure log, e.g. "[search] BAN". */
  logLabel: string;
};

/**
 * One JSON round-trip to an upstream the API must survive losing. Never
 * throws — an upstream outage must degrade the response, not turn it into a
 * 500. `null` means "the upstream did not answer"; the caller decides what
 * that costs.
 */
export async function fetchJsonOrNull(
  url: URL,
  { headers, signal, timeoutMs, logLabel }: FetchJsonOptions
): Promise<unknown | null> {
  const timeout = AbortSignal.timeout(timeoutMs);

  try {
    const response = await fetch(url, {
      headers,
      signal: signal ? AbortSignal.any([timeout, signal]) : timeout,
    });
    if (!response.ok) throw new Error(`${logLabel} responded ${response.status}`);
    return await response.json();
  } catch (cause) {
    console.error(`${logLabel} indisponible`, cause);
    return null;
  }
}
