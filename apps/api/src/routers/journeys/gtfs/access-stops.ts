/**
 * Which stops a journey may start from, or end at, given a point on the map.
 *
 * Pure on purpose: the rule below decides whether a whole town is reachable,
 * and it should be readable — and testable — without a network.
 */

/**
 * Slots reserved for the nearest métro, RER, Transilien or tram stop, on top of
 * the nearest stops of any mode.
 *
 * Ordering access strictly by distance is right in town, where the eight
 * nearest stops of a dense network already include a métro entrance. It is
 * wrong in a suburb: eight bus poles within four hundred metres crowd out the
 * RER station nine hundred metres away — the one stop that actually leaves the
 * area. The search then starts on bus lines only, needs a connection
 * `transfers.txt` does not declare, and reports that no itinerary exists at
 * all. Reserving slots for the walkable station is what keeps a suburban
 * address connected to the network it is plainly next to.
 */
export const STRUCTURING_ACCESS_STOPS = 4;

/**
 * The nearest stops of any mode, plus the nearest stations, each list already
 * ordered by distance and neither dropping the other's entries.
 *
 * The result can exceed either list's own limit: the reserved slots are an
 * addition to the access set, not a share of it.
 */
export function mergeAccessStops<T extends { id: string }>(
  nearest: readonly T[],
  structuring: readonly T[]
): T[] {
  const merged: T[] = [];
  const seen = new Set<string>();
  for (const stop of [...nearest, ...structuring]) {
    if (seen.has(stop.id)) continue;
    seen.add(stop.id);
    merged.push(stop);
  }
  return merged;
}
