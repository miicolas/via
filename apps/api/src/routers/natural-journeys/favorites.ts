import { and, eq, inArray } from 'drizzle-orm';
import { accountPlaces, db } from '@via/db';
import type { SearchResult } from '@via/contract';

export type NaturalJourneyFavorites = { home?: SearchResult; work?: SearchResult };

export type FavoritesReader = (userId: string) => Promise<NaturalJourneyFavorites>;

/**
 * The account's Home/Work slots, shaped for the toolset. One indexed read on
 * `(userId, role)`; an anonymous submission never gets here.
 */
export async function readNaturalJourneyFavorites(
  userId: string
): Promise<NaturalJourneyFavorites> {
  const rows = await db
    .select()
    .from(accountPlaces)
    .where(and(eq(accountPlaces.userId, userId), inArray(accountPlaces.role, ['home', 'work'])));

  const favorites: NaturalJourneyFavorites = {};
  for (const row of rows) {
    const result = toSearchResult(row);
    if (!result) continue;
    if (row.role === 'home') favorites.home = result;
    else favorites.work = result;
  }
  return favorites;
}

type AccountPlaceRow = typeof accountPlaces.$inferSelect;

/**
 * `account_places.id` stores the client identifier, which prefixes the raw id
 * with its kind ("station:IDFM:…", "address:75104_…") — the mirror of the
 * app's `SearchResultID.encode`. The planner wants the raw id back.
 */
function toSearchResult(row: AccountPlaceRow): SearchResult | undefined {
  const id = stripKindPrefix(row.id, row.kind);
  const coordinate = { latitude: row.latitude, longitude: row.longitude };
  switch (row.kind) {
    case 'station':
      return { kind: 'station', id, name: row.name, coordinate, routes: [] };
    case 'address':
      return { kind: 'address', id, name: row.name, coordinate, context: row.context ?? '' };
    default:
      return undefined;
  }
}

function stripKindPrefix(id: string, kind: string): string {
  const prefix = `${kind}:`;
  return id.startsWith(prefix) ? id.slice(prefix.length) : id;
}
