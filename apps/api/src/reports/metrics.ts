export type ReportMetric = {
  operation: 'submit' | 'read';
  outcome:
    | 'accepted'
    | 'idempotent'
    | 'rate-limited'
    | 'redis-unavailable'
    | 'cache-hit'
    | 'cache-miss'
    | 'not-found';
  latencyMs: number;
  activeStates: number;
};

/** Deliberately excludes station, account, network address, category and free text. */
export function recordReportMetric(metric: ReportMetric) {
  console.info('[reports] aggregate', metric);
}
