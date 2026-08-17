import { and, desc, eq, isNull, lte, ne, or, sql } from 'drizzle-orm';
import type { PgColumn, PgTable } from 'drizzle-orm/pg-core';
import {
  accountFavoriteStations,
  accountPlaces,
  accountRecentSearches,
  accountSyncOperations,
  db,
  NETWORK_MODES,
  users,
  type NetworkMode,
} from '@via/db';
import {
  ACCOUNT_FAVORITE_LIMIT,
  ACCOUNT_PLACE_FAVORITE_LIMIT,
  ACCOUNT_RECENT_LIMIT,
  type AccountSyncInput,
  type AccountSyncResponse,
} from '@via/contract';

export async function synchronizeAccount(
  userId: string,
  input: AccountSyncInput
): Promise<AccountSyncResponse> {
  await db.transaction(async (transaction) => {
    for (const operation of input.operations) {
      const inserted = await transaction
        .insert(accountSyncOperations)
        .values({ operationId: operation.operationId, userId })
        .onConflictDoNothing()
        .returning({ operationId: accountSyncOperations.operationId });

      if (inserted.length === 0) continue;

      switch (operation.kind) {
        case 'favorite.upsert': {
          if (!operation.station) break;
          const station = operation.station;
          // A favorite without a coordinate must not erase a stored one.
          await transaction
            .insert(accountFavoriteStations)
            .values({
              userId,
              stationId: station.stationId,
              name: station.name,
              ...(station.coordinate ?? {}),
              savedAt: new Date(station.savedAt),
              updatedAt: new Date(station.updatedAt),
            })
            .onConflictDoUpdate({
              target: [accountFavoriteStations.userId, accountFavoriteStations.stationId],
              set: {
                name: station.name,
                ...(station.coordinate ?? {}),
                savedAt: new Date(station.savedAt),
                updatedAt: new Date(station.updatedAt),
              },
              setWhere: lte(accountFavoriteStations.updatedAt, new Date(station.updatedAt)),
            });
          break;
        }

        case 'favorite.remove':
          if (operation.stationId) {
            await transaction
              .delete(accountFavoriteStations)
              .where(
                and(
                  eq(accountFavoriteStations.userId, userId),
                  eq(accountFavoriteStations.stationId, operation.stationId),
                  lte(accountFavoriteStations.updatedAt, new Date(operation.occurredAt))
                )
              );
          }
          break;

        case 'recent.upsert': {
          if (!operation.recent) break;
          const recent = operation.recent;
          await transaction
            .insert(accountRecentSearches)
            .values({
              userId,
              id: recent.id,
              kind: recent.kind,
              name: recent.name,
              context: recent.context ?? null,
              latitude: recent.coordinate.latitude,
              longitude: recent.coordinate.longitude,
              savedAt: new Date(recent.savedAt),
            })
            .onConflictDoUpdate({
              target: [accountRecentSearches.userId, accountRecentSearches.id],
              set: {
                kind: recent.kind,
                name: recent.name,
                context: recent.context ?? null,
                latitude: recent.coordinate.latitude,
                longitude: recent.coordinate.longitude,
                savedAt: new Date(recent.savedAt),
              },
              setWhere: lte(accountRecentSearches.savedAt, new Date(recent.savedAt)),
            });
          break;
        }

        case 'recent.remove':
          if (operation.recentId) {
            await transaction
              .delete(accountRecentSearches)
              .where(
                and(
                  eq(accountRecentSearches.userId, userId),
                  eq(accountRecentSearches.id, operation.recentId),
                  lte(accountRecentSearches.savedAt, new Date(operation.occurredAt))
                )
              );
          }
          break;

        case 'recent.clear':
          await transaction
            .delete(accountRecentSearches)
            .where(
              and(
                eq(accountRecentSearches.userId, userId),
                lte(accountRecentSearches.savedAt, new Date(operation.occurredAt))
              )
            );
          break;

        case 'place.upsert': {
          if (!operation.place) break;
          const place = operation.place;
          if (place.role !== 'favorite') {
            // Home and work are unique per user: reassigning the role evicts
            // the previous holder, last writer wins on `updatedAt`.
            await transaction
              .delete(accountPlaces)
              .where(
                and(
                  eq(accountPlaces.userId, userId),
                  eq(accountPlaces.role, place.role),
                  ne(accountPlaces.id, place.id),
                  lte(accountPlaces.updatedAt, new Date(place.updatedAt))
                )
              );
          }
          await transaction
            .insert(accountPlaces)
            .values({
              userId,
              id: place.id,
              role: place.role,
              kind: place.kind,
              name: place.name,
              context: place.context ?? null,
              latitude: place.coordinate.latitude,
              longitude: place.coordinate.longitude,
              savedAt: new Date(place.savedAt),
              updatedAt: new Date(place.updatedAt),
            })
            .onConflictDoUpdate({
              target: [accountPlaces.userId, accountPlaces.id],
              set: {
                role: place.role,
                kind: place.kind,
                name: place.name,
                context: place.context ?? null,
                latitude: place.coordinate.latitude,
                longitude: place.coordinate.longitude,
                savedAt: new Date(place.savedAt),
                updatedAt: new Date(place.updatedAt),
              },
              setWhere: lte(accountPlaces.updatedAt, new Date(place.updatedAt)),
            });
          break;
        }

        case 'place.remove':
          if (operation.placeId) {
            await transaction
              .delete(accountPlaces)
              .where(
                and(
                  eq(accountPlaces.userId, userId),
                  eq(accountPlaces.id, operation.placeId),
                  lte(accountPlaces.updatedAt, new Date(operation.occurredAt))
                )
              );
          }
          break;

        case 'preferences.set': {
          if (!operation.preferences) break;
          const preferences = operation.preferences;
          // Preferences live as Better Auth `additionalFields` on the user
          // row; last writer wins on `preferencesUpdatedAt`.
          await transaction
            .update(users)
            .set({
              preferredModes: preferences.preferredModes,
              excludedModes: preferences.excludedModes,
              preferencesUpdatedAt: new Date(preferences.updatedAt),
            })
            .where(
              and(
                eq(users.id, userId),
                or(
                  isNull(users.preferencesUpdatedAt),
                  lte(users.preferencesUpdatedAt, new Date(preferences.updatedAt))
                )
              )
            );
          break;
        }
      }
    }

    await trimOldest(transaction, userId, {
      table: accountFavoriteStations,
      idColumn: accountFavoriteStations.stationId,
      savedAtColumn: accountFavoriteStations.savedAt,
      userIdColumn: accountFavoriteStations.userId,
      limit: ACCOUNT_FAVORITE_LIMIT,
    });
    await trimOldest(transaction, userId, {
      table: accountRecentSearches,
      idColumn: accountRecentSearches.id,
      savedAtColumn: accountRecentSearches.savedAt,
      userIdColumn: accountRecentSearches.userId,
      limit: ACCOUNT_RECENT_LIMIT,
    });
    if (input.operations.some((operation) => operation.kind === 'place.upsert')) {
      // Home and work never get trimmed; only surplus favorite places do.
      await trimOldest(transaction, userId, {
        table: accountPlaces,
        idColumn: accountPlaces.id,
        savedAtColumn: accountPlaces.savedAt,
        userIdColumn: accountPlaces.userId,
        limit: ACCOUNT_PLACE_FAVORITE_LIMIT,
        condition: sql`${accountPlaces.role} = 'favorite'`,
      });
    }
  });

  const [favorites, recents, places, preferences] = await Promise.all([
    db
      .select()
      .from(accountFavoriteStations)
      .where(eq(accountFavoriteStations.userId, userId))
      .orderBy(desc(accountFavoriteStations.savedAt)),
    db
      .select()
      .from(accountRecentSearches)
      .where(eq(accountRecentSearches.userId, userId))
      .orderBy(desc(accountRecentSearches.savedAt)),
    db
      .select()
      .from(accountPlaces)
      .where(eq(accountPlaces.userId, userId))
      .orderBy(desc(accountPlaces.savedAt)),
    db
      .select({
        preferredModes: users.preferredModes,
        excludedModes: users.excludedModes,
        updatedAt: users.preferencesUpdatedAt,
      })
      .from(users)
      .where(eq(users.id, userId))
      .limit(1),
  ]);

  const syncedAt = new Date();
  const storedPreferences = preferences[0];
  return {
    appliedOperationIds: input.operations.map((operation) => operation.operationId),
    favorites: favorites.map((favorite) => ({
      stationId: favorite.stationId,
      name: favorite.name,
      coordinate:
        favorite.latitude !== null && favorite.longitude !== null
          ? { latitude: favorite.latitude, longitude: favorite.longitude }
          : undefined,
      savedAt: favorite.savedAt.toISOString(),
      updatedAt: favorite.updatedAt.toISOString(),
    })),
    recents: recents.map((recent) => ({
      id: recent.id,
      kind: recent.kind === 'address' ? ('address' as const) : ('station' as const),
      name: recent.name,
      context: recent.context ?? undefined,
      coordinate: { latitude: recent.latitude, longitude: recent.longitude },
      savedAt: recent.savedAt.toISOString(),
    })),
    places: places.map((place) => ({
      id: place.id,
      kind: place.kind,
      name: place.name,
      context: place.context ?? undefined,
      coordinate: { latitude: place.latitude, longitude: place.longitude },
      role: place.role,
      savedAt: place.savedAt.toISOString(),
      updatedAt: place.updatedAt.toISOString(),
    })),
    preferences: {
      preferredModes: parseModes(storedPreferences?.preferredModes),
      excludedModes: parseModes(storedPreferences?.excludedModes),
      updatedAt: (storedPreferences?.updatedAt ?? syncedAt).toISOString(),
    },
    syncedAt: syncedAt.toISOString(),
  };
}

function parseModes(values: string[] | undefined) {
  return (values ?? []).filter((mode): mode is NetworkMode =>
    (NETWORK_MODES as readonly string[]).includes(mode)
  );
}

/**
 * Keeps only the `limit` most recently saved rows for this user, optionally
 * restricted to the rows matching `condition`.
 */
async function trimOldest(
  transaction: Parameters<Parameters<typeof db.transaction>[0]>[0],
  userId: string,
  scope: {
    table: PgTable;
    idColumn: PgColumn;
    savedAtColumn: PgColumn;
    userIdColumn: PgColumn;
    limit: number;
    condition?: ReturnType<typeof sql>;
  }
) {
  const condition = scope.condition ?? sql`TRUE`;
  await transaction.execute(sql`
    DELETE FROM ${scope.table}
    WHERE ${scope.userIdColumn} = ${userId}
      AND ${condition}
      AND ${scope.idColumn} NOT IN (
        SELECT ${scope.idColumn} FROM ${scope.table}
        WHERE ${scope.userIdColumn} = ${userId}
          AND ${condition}
        ORDER BY ${scope.savedAtColumn} DESC
        LIMIT ${scope.limit}
      )
  `);
}
