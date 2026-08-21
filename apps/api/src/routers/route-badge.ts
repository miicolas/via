import type { RouteBadge } from '@via/contract';
import { networkMode } from '@via/db/schema';

const MODE_ORDER: Record<RouteBadge['mode'], number> = {
  metro: 0,
  rer: 1,
  transilien: 2,
  tram: 3,
  bus: 4,
};

/** Built once: `localeCompare` allocates a fresh collator on every call. */
const SHORT_NAME_ORDER = new Intl.Collator('fr', { numeric: true });

/** The GTFS route columns a badge is built from, as the routers' queries return them. */
export type RouteBadgeRow = {
  id: string;
  shortName: string;
  routeType: number;
  color: string;
  textColor: string;
};

/**
 * GTFS route metadata → the badge the contract inlines everywhere a route is
 * mentioned. One converter for network, search and departures, so `#`-prefixed
 * colors and the mode mapping can never drift between screens.
 */
export function toRouteBadge(row: RouteBadgeRow): RouteBadge {
  const mode = networkMode(row.routeType, row.shortName);
  if (!mode) throw new Error(`Unsupported route ${row.id}`);

  return {
    id: row.id,
    shortName: row.shortName,
    mode,
    color: `#${row.color}`,
    textColor: `#${row.textColor}`,
  };
}

/** Presentation order shared by every compact list of line badges. */
export function compareRouteBadges(left: RouteBadge, right: RouteBadge): number {
  return (
    MODE_ORDER[left.mode] - MODE_ORDER[right.mode] ||
    SHORT_NAME_ORDER.compare(left.shortName, right.shortName)
  );
}
