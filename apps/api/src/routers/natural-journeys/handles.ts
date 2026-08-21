import type {
  JourneysResponse,
  NaturalJourneyInterpretation,
  SearchResult,
} from '@via/contract';

export type PlanEntry = {
  interpretation: NaturalJourneyInterpretation;
  journeys: JourneysResponse;
};

/**
 * The opaque handle registry, scoped to a single submission. The model only
 * ever sees `place_1`, `plan_1`… — never coordinates, ids, or the resolved
 * itinerary. It resolves places through Via, refers to them by handle, and the
 * server keeps the real objects here. That is what makes Via the authority: a
 * handle the server did not mint cannot be resolved, so the model cannot smuggle
 * in a place or plan of its own invention.
 */
export type HandleRegistry = {
  registerPlace: (result: SearchResult) => string;
  resolvePlace: (handle: string) => SearchResult | null;
  registerPlan: (entry: PlanEntry) => string;
  resolvePlan: (handle: string) => PlanEntry | null;
};

export function createHandleRegistry(): HandleRegistry {
  const places = new Map<string, SearchResult>();
  const plans = new Map<string, PlanEntry>();
  let placeSeq = 0;
  let planSeq = 0;
  return {
    registerPlace: (result) => {
      const handle = `place_${(placeSeq += 1)}`;
      places.set(handle, result);
      return handle;
    },
    resolvePlace: (handle) => places.get(handle) ?? null,
    registerPlan: (entry) => {
      const handle = `plan_${(planSeq += 1)}`;
      plans.set(handle, entry);
      return handle;
    },
    resolvePlan: (handle) => plans.get(handle) ?? null,
  };
}
