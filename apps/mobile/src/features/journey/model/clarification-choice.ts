import type { SearchResult } from '@via/contract';

/** One answer to a natural-journey clarification: a picked place, or the time's meaning. */
export type NaturalJourneyChoice =
  | { target: 'origin' | 'destination'; result: SearchResult }
  | { target: 'time'; value: 'departure' | 'arrival' };
