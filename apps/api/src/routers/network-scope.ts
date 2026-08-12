import {
  RER_SHORT_NAMES,
  ROUTE_TYPE,
  transitRoutes,
} from '@via/db/schema';
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
    eq(transitRoutes.routeType, ROUTE_TYPE.metro),
    and(
      eq(transitRoutes.routeType, ROUTE_TYPE.rail),
      inArray(transitRoutes.shortName, [...RER_SHORT_NAMES])
    )
  );
}

export function busRouteCondition() {
  return eq(transitRoutes.routeType, ROUTE_TYPE.bus);
}
