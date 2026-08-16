import {
  METRO_SHORT_NAMES,
  RER_SHORT_NAMES,
  ROUTE_TYPE,
  TRAM_SHORT_NAMES,
  TRANSILIEN_SHORT_NAMES,
  transitRoutes,
} from './schema';
import { and, eq, inArray, or } from 'drizzle-orm';

/** The exact route subset shared by the network map and station search. */
export function networkRouteCondition() {
  return or(
    drawnRouteCondition(),
    busRouteCondition()
  );
}

export function drawnRouteCondition() {
  return or(
    and(
      eq(transitRoutes.routeType, ROUTE_TYPE.metro),
      inArray(transitRoutes.shortName, [...METRO_SHORT_NAMES])
    ),
    and(
      eq(transitRoutes.routeType, ROUTE_TYPE.tram),
      inArray(transitRoutes.shortName, [...TRAM_SHORT_NAMES])
    ),
    and(
      eq(transitRoutes.routeType, ROUTE_TYPE.rail),
      inArray(transitRoutes.shortName, [
        ...RER_SHORT_NAMES,
        ...TRANSILIEN_SHORT_NAMES,
      ])
    )
  );
}

export function busRouteCondition() {
  return eq(transitRoutes.routeType, ROUTE_TYPE.bus);
}
