import {
  createSearchParamsCache,
  parseAsInteger,
  parseAsStringLiteral,
} from "nuqs/server";

/**
 * Only navigable presentation state belongs in the URL. The share token is a
 * route segment and the journey itself comes from the hydrated server query.
 */
export const journeySearchParams = {
  leg: parseAsInteger.withDefault(0),
  view: parseAsStringLiteral(["map", "details"] as const).withDefault(
    "details",
  ),
};

export const journeySearchParamsCache =
  createSearchParamsCache(journeySearchParams);
