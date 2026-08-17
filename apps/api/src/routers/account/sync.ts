import { and, desc, eq, isNull, lte, or, sql } from 'drizzle-orm';
import type { PgColumn, PgTable } from 'drizzle-orm/pg-core';
import {
  accountFavoriteStations,
  accountRecentSearches,
  accountSyncOperations,
  db,
  NETWORK_MODES,
  users,
  type NetworkMode,
} from '@via/db';
import {
  ACCOUNT_FAVORITE_LIMIT,
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
          await transaction
            .insert(accountFavoriteStations)
            .values({
              userId,
              stationId: station.stationId,
              name: station.name,
              savedAt: new Date(station.savedAt),
              updatedAt: new Date(station.updatedAt),
            })
            .onConflictDoUpdate({
              target: [accountFavoriteStations.userId, accountFavoriteStations.stationId],
              set: {
                name: station.name,
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
  });

  const [favorites, recents, preferences] = await Promise.all([
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

/** Keeps only the `limit` most recently saved rows for this user. */
async function trimOldest(
  transaction: Parameters<Parameters<typeof db.transaction>[0]>[0],
  userId: string,
  scope: {
    table: PgTable;
    idColumn: PgColumn;
    savedAtColumn: PgColumn;
    userIdColumn: PgColumn;
    limit: number;
  }
) {
  await transaction.execute(sql`
    DELETE FROM ${scope.table}
    WHERE ${scope.userIdColumn} = ${userId}
      AND ${scope.idColumn} NOT IN (
        SELECT ${scope.idColumn} FROM ${scope.table}
        WHERE ${scope.userIdColumn} = ${userId}
        ORDER BY ${scope.savedAtColumn} DESC
        LIMIT ${scope.limit}
      )
  `);
}
