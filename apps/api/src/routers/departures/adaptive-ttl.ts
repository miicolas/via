const BASE_TTL_SECONDS = 120;

/**
 * How long a fresh PRIM payload may be served before the next upstream call.
 * Pure so the governor is testable without a clock: feed it the budget ratio,
 * read back the TTL. Spending on pace keeps the base freshness; burning ahead
 * of pace doubles then quadruples the TTL, trading staleness for staying
 * inside the daily quota.
 */
export function adaptiveTtlSeconds(budgetRatio: number): number {
  if (budgetRatio > 1.6) return BASE_TTL_SECONDS * 4;
  if (budgetRatio > 1) return BASE_TTL_SECONDS * 2;
  return BASE_TTL_SECONDS;
}
