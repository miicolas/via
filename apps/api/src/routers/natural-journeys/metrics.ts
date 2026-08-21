/**
 * Everything we are allowed to record about a fallback submission — and nothing
 * else. There is deliberately no field for the phrase, resolved places,
 * coordinates, handles, or the itinerary: those never leave the request. A
 * reviewer can confirm the privacy promise by reading this type alone.
 */
export type NaturalJourneyOutcomeCategory =
  | 'ready'
  | 'unsupported'
  | 'no-key'
  | 'rate-limited'
  | 'circuit-open'
  | 'timeout'
  | 'cancelled'
  | 'invalid-output'
  | 'tool-budget-exceeded'
  | 'openai-error';

export type TokenUsage = { input: number; output: number; total: number };

export type NaturalJourneyMetric = {
  source: 'openai';
  category: NaturalJourneyOutcomeCategory;
  latencyMs: number;
  toolCalls: { searchPlaces: number; planJourneys: number };
  tokens: TokenUsage | null;
  model: string;
  promptVersion: string;
  costUsd: number | null;
};

export type TokenPricing = {
  /** USD per million input tokens. */
  inputPerMillion: number;
  /** USD per million output tokens. */
  outputPerMillion: number;
};

/** Null when either the usage or the pricing is unknown — never a misleading 0. */
export function computeCostUsd(
  tokens: TokenUsage | null,
  pricing: TokenPricing | null
): number | null {
  if (!tokens || !pricing) return null;
  const cost =
    (tokens.input * pricing.inputPerMillion + tokens.output * pricing.outputPerMillion) /
    1_000_000;
  return Math.round(cost * 1_000_000) / 1_000_000;
}

export function recordNaturalJourneyMetric(metric: NaturalJourneyMetric): void {
  console.info('[natural-journeys] submission', metric);
}
