/**
 * The ceilings one GTFS search may spend, owned by the planner and handed to
 * the loader as plain parameters wherever a query must enforce one in SQL.
 *
 * Every field is a planning decision, not a query mechanic: changing one
 * changes which journeys are findable, so they live together here instead of
 * hiding inside the Postgres adapter.
 */
export type SearchBudget = {
  /** The nearest stops of any mode a journey may start from or end at. */
  maxAccessStops: number;
  /**
   * Slots reserved for the nearest métro, RER, Transilien or tram stop, on
   * top of the nearest stops of any mode.
   *
   * Ordering access strictly by distance is right in town, where the eight
   * nearest stops of a dense network already include a métro entrance. It is
   * wrong in a suburb: eight bus poles within four hundred metres crowd out
   * the RER station nine hundred metres away — the one stop that actually
   * leaves the area. The search then starts on bus lines only, needs a
   * connection `transfers.txt` does not declare, and reports that no
   * itinerary exists at all. Reserving slots for the walkable station is what
   * keeps a suburban address connected to the network it is plainly next to.
   */
  structuringAccessStops: number;
  /** Boardings (or alightings) one stop may keep once candidates are ranked. */
  maxBoardingsPerStop: number;
  /** Rows a single candidate query may return, and the ceiling after merging. */
  maxStopTimeCandidates: number;
  /** Ceiling on the extra queries a widely spread frontier may cost. */
  maxBoundGroups: number;
  /**
   * How far apart two frontier stops may be reached before they stop sharing
   * a candidate query. Below it the frontier is one time window and one
   * query, the behaviour every short search has always had.
   */
  boundGroupSpreadSeconds: number;
};

export const DEFAULT_SEARCH_BUDGET: SearchBudget = {
  maxAccessStops: 8,
  structuringAccessStops: 4,
  maxBoardingsPerStop: 32,
  maxStopTimeCandidates: 1_500,
  maxBoundGroups: 4,
  boundGroupSpreadSeconds: 300,
};
