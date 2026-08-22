/**
 * Derive the drawn geometry one route at a time.
 *
 * The computation is already partitioned by route — every join and every window
 * in it stays inside one `route_id` — so splitting it changes no result. What it
 * changes is the failure mode: one route's PostGIS work is a statement small
 * enough to carry a timeout, and a route whose shapes make GEOS crawl names
 * itself in the error instead of hiding inside a single network-wide UPDATE that
 * can only be watched or killed.
 *
 * Strictly sequential: these are the heaviest spatial statements the importer
 * runs, and the database serving them is also serving the API.
 */
export async function deriveDrawnGeometryByRoute(
  routeIds: readonly string[],
  deriveRoute: (routeId: string, index: number, total: number) => Promise<unknown>
): Promise<void> {
  for (const [index, routeId] of routeIds.entries()) {
    try {
      await deriveRoute(routeId, index, routeIds.length);
    } catch (cause) {
      const reason = cause instanceof Error ? cause.message : String(cause);
      throw new Error(`Could not compute drawn geometry for route ${routeId}: ${reason}`, {
        cause,
      });
    }
  }
}
