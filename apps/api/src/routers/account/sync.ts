import { and, desc, eq, isNull, lte, ne, or, sql } from 'drizzle-orm';
import type { PgColumn, PgTable } from 'drizzle-orm/pg-core';
import {
  accountFavoriteStations,
  accountPlaces,
  accountRecentSearches,
  accountSyncOperations,
  db,
  NETWORK_MODES,
  notificationAlertSubscriptions,
  notificationPreferences,
  notificationSchedules,
  users,
  type NetworkMode,
} from '@via/db';
import {
  ACCOUNT_FAVORITE_LIMIT,
  NOTIFICATION_ALERT_LIMIT,
  NOTIFICATION_SCHEDULE_LIMIT,
  ACCOUNT_RECENT_LIMIT,
  type AccountSyncInput,
  type AccountSyncResponse,
} from '@via/contract';
import {
  defaultNotificationPreferences,
  mergeNotificationPreferences,
} from '../../notifications/preferences';

const ACCOUNT_SYNC_OPERATION_LIMIT = 10_000;
const ACCOUNT_SYNC_OPERATION_RETENTION_DAYS = 90;
const ACCOUNT_SYNC_OPERATION_PURGE_BATCH = 1_000;

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

        case 'notifications.preferences.set': {
          if (!operation.notificationPreferences) break;
          const preferences = operation.notificationPreferences;
          await transaction
            .insert(notificationPreferences)
            .values({
              userId,
              enabled: preferences.enabled,
              timeZone: 'Europe/Paris',
              quietHoursStartMinute: preferences.quietHoursStartMinute ?? null,
              quietHoursEndMinute: preferences.quietHoursEndMinute ?? null,
              mutedOnWeekends: preferences.mutedOnWeekends,
              mutedOnHolidays: preferences.mutedOnHolidays,
              minimumSeverity: preferences.minimumSeverity,
              dailyCap: preferences.dailyCap ?? 20,
              categories: preferences.categories,
              updatedAt: new Date(preferences.updatedAt),
            })
            .onConflictDoUpdate({
              target: notificationPreferences.userId,
              set: {
                enabled: preferences.enabled,
                timeZone: 'Europe/Paris',
                quietHoursStartMinute: preferences.quietHoursStartMinute ?? null,
                quietHoursEndMinute: preferences.quietHoursEndMinute ?? null,
                mutedOnWeekends: preferences.mutedOnWeekends,
                mutedOnHolidays: preferences.mutedOnHolidays,
                minimumSeverity: preferences.minimumSeverity,
                dailyCap: preferences.dailyCap ?? 20,
                categories: preferences.categories,
                updatedAt: new Date(preferences.updatedAt),
              },
              setWhere: lte(notificationPreferences.updatedAt, new Date(preferences.updatedAt)),
            });
          break;
        }

        case 'notifications.schedule.upsert': {
          if (!operation.schedule) break;
          const schedule = operation.schedule;
          await transaction
            .insert(notificationSchedules)
            .values({
              id: schedule.id,
              userId,
              kind: schedule.kind,
              label: schedule.label,
              revision: schedule.revision,
              origin: schedule.origin ?? null,
              destination: schedule.destination ?? null,
              routeIds: schedule.routeIds,
              daysOfWeek: schedule.daysOfWeek,
              departureMinute: schedule.departureMinute,
              leadMinutes: schedule.leadMinutes,
              skipHolidays: schedule.skipHolidays,
              enabled: schedule.enabled,
              pausedUntil: schedule.pausedUntil ? new Date(schedule.pausedUntil) : null,
              timeZone: 'Europe/Paris',
              savedAt: new Date(schedule.savedAt),
              updatedAt: new Date(schedule.updatedAt),
              deletedAt: schedule.deletedAt ? new Date(schedule.deletedAt) : null,
            })
            .onConflictDoUpdate({
              target: notificationSchedules.id,
              set: {
                kind: schedule.kind,
                label: schedule.label,
                revision: sql`${notificationSchedules.revision} + 1`,
                origin: schedule.origin ?? null,
                destination: schedule.destination ?? null,
                routeIds: schedule.routeIds,
                daysOfWeek: schedule.daysOfWeek,
                departureMinute: schedule.departureMinute,
                leadMinutes: schedule.leadMinutes,
                skipHolidays: schedule.skipHolidays,
                enabled: schedule.enabled,
                pausedUntil: schedule.pausedUntil ? new Date(schedule.pausedUntil) : null,
                timeZone: 'Europe/Paris',
                savedAt: new Date(schedule.savedAt),
                updatedAt: new Date(schedule.updatedAt),
                deletedAt: schedule.deletedAt ? new Date(schedule.deletedAt) : null,
              },
              setWhere: and(
                eq(notificationSchedules.userId, userId),
                lte(notificationSchedules.updatedAt, new Date(schedule.updatedAt)),
              ),
            });
          break;
        }

        case 'notifications.schedule.remove':
          if (operation.scheduleId) {
            await transaction
              .update(notificationSchedules)
              .set({
                enabled: false,
                deletedAt: new Date(operation.occurredAt),
                updatedAt: new Date(operation.occurredAt),
                revision: sql`${notificationSchedules.revision} + 1`,
              })
              .where(
                and(
                  eq(notificationSchedules.userId, userId),
                  eq(notificationSchedules.id, operation.scheduleId),
                  lte(notificationSchedules.updatedAt, new Date(operation.occurredAt)),
                ),
              );
          }
          break;

        case 'notifications.alert.upsert': {
          if (!operation.alertSubscription) break;
          const alert = operation.alertSubscription;
          await transaction
            .insert(notificationAlertSubscriptions)
            .values({
              id: alert.id,
              userId,
              topicKind: alert.topicKind,
              topicId: alert.topicId,
              label: alert.label,
              daysOfWeek: alert.daysOfWeek,
              windows: alert.windows,
              minimumSeverity: alert.minimumSeverity,
              enabled: alert.enabled,
              savedAt: new Date(alert.savedAt),
              updatedAt: new Date(alert.updatedAt),
              deletedAt: alert.deletedAt ? new Date(alert.deletedAt) : null,
            })
            .onConflictDoUpdate({
              target: notificationAlertSubscriptions.id,
              set: {
                topicKind: alert.topicKind,
                topicId: alert.topicId,
                label: alert.label,
                daysOfWeek: alert.daysOfWeek,
                windows: alert.windows,
                minimumSeverity: alert.minimumSeverity,
                enabled: alert.enabled,
                savedAt: new Date(alert.savedAt),
                updatedAt: new Date(alert.updatedAt),
                deletedAt: alert.deletedAt ? new Date(alert.deletedAt) : null,
              },
              setWhere: and(
                eq(notificationAlertSubscriptions.userId, userId),
                lte(notificationAlertSubscriptions.updatedAt, new Date(alert.updatedAt)),
              ),
            });
          break;
        }

        case 'notifications.alert.remove':
          if (operation.alertSubscriptionId) {
            await transaction
              .update(notificationAlertSubscriptions)
              .set({
                enabled: false,
                deletedAt: new Date(operation.occurredAt),
                updatedAt: new Date(operation.occurredAt),
              })
              .where(
                and(
                  eq(notificationAlertSubscriptions.userId, userId),
                  eq(notificationAlertSubscriptions.id, operation.alertSubscriptionId),
                  lte(notificationAlertSubscriptions.updatedAt, new Date(operation.occurredAt)),
                ),
              );
          }
          break;
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
    await trimOldest(transaction, userId, {
      table: notificationSchedules,
      idColumn: notificationSchedules.id,
      savedAtColumn: notificationSchedules.savedAt,
      userIdColumn: notificationSchedules.userId,
      limit: NOTIFICATION_SCHEDULE_LIMIT,
      condition: sql`${notificationSchedules.deletedAt} IS NULL`,
    });
    await trimOldest(transaction, userId, {
      table: notificationAlertSubscriptions,
      idColumn: notificationAlertSubscriptions.id,
      savedAtColumn: notificationAlertSubscriptions.savedAt,
      userIdColumn: notificationAlertSubscriptions.userId,
      limit: NOTIFICATION_ALERT_LIMIT,
      condition: sql`${notificationAlertSubscriptions.deletedAt} IS NULL`,
    });
    await trimOldest(transaction, userId, {
      table: accountSyncOperations,
      idColumn: accountSyncOperations.operationId,
      savedAtColumn: accountSyncOperations.appliedAt,
      userIdColumn: accountSyncOperations.userId,
      limit: ACCOUNT_SYNC_OPERATION_LIMIT,
    });
    await transaction.execute(sql`
      DELETE FROM account_sync_operations AS operation
      WHERE operation.operation_id IN (
        SELECT candidate.operation_id
        FROM account_sync_operations AS candidate
        WHERE candidate.user_id = ${userId}
          AND candidate.applied_at < now() - (${ACCOUNT_SYNC_OPERATION_RETENTION_DAYS} * interval '1 day')
        ORDER BY candidate.applied_at, candidate.operation_id
        LIMIT ${ACCOUNT_SYNC_OPERATION_PURGE_BATCH}
      )
    `);
  });

  const [favorites, recents, places, preferences, storedNotificationPreferences, schedules, alerts] = await Promise.all([
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
    db
      .select()
      .from(notificationPreferences)
      .where(eq(notificationPreferences.userId, userId))
      .limit(1),
    db
      .select()
      .from(notificationSchedules)
      .where(
        and(
          eq(notificationSchedules.userId, userId),
          isNull(notificationSchedules.deletedAt),
        ),
      )
      .orderBy(desc(notificationSchedules.savedAt)),
    db
      .select()
      .from(notificationAlertSubscriptions)
      .where(
        and(
          eq(notificationAlertSubscriptions.userId, userId),
          isNull(notificationAlertSubscriptions.deletedAt),
        ),
      )
      .orderBy(desc(notificationAlertSubscriptions.savedAt)),
  ]);

  const syncedAt = new Date();
  const storedPreferences = preferences[0];
  const notificationPreference = mergeNotificationPreferences(
    storedNotificationPreferences[0]
      ? {
          enabled: storedNotificationPreferences[0].enabled,
          timeZone: 'Europe/Paris',
          quietHoursStartMinute: storedNotificationPreferences[0].quietHoursStartMinute ?? undefined,
          quietHoursEndMinute: storedNotificationPreferences[0].quietHoursEndMinute ?? undefined,
          mutedOnWeekends: storedNotificationPreferences[0].mutedOnWeekends,
          mutedOnHolidays: storedNotificationPreferences[0].mutedOnHolidays,
          minimumSeverity: storedNotificationPreferences[0].minimumSeverity,
          dailyCap: storedNotificationPreferences[0].dailyCap,
          categories: storedNotificationPreferences[0].categories,
          updatedAt: storedNotificationPreferences[0].updatedAt.toISOString(),
        }
      : defaultNotificationPreferences(syncedAt),
    syncedAt,
  );

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
    notificationPreferences: notificationPreference,
    notificationSchedules: schedules.map(toNotificationSchedule),
    notificationAlerts: alerts.map(toNotificationAlert),
    syncedAt: syncedAt.toISOString(),
  };
}

function toNotificationSchedule(schedule: typeof notificationSchedules.$inferSelect) {
  return {
    id: schedule.id,
    kind: schedule.kind,
    label: schedule.label,
    revision: schedule.revision,
    origin: schedule.origin ?? undefined,
    destination: schedule.destination ?? undefined,
    routeIds: schedule.routeIds,
    daysOfWeek: schedule.daysOfWeek,
    departureMinute: schedule.departureMinute,
    leadMinutes: schedule.leadMinutes,
    skipHolidays: schedule.skipHolidays,
    enabled: schedule.enabled,
    pausedUntil: schedule.pausedUntil?.toISOString(),
    timeZone: 'Europe/Paris' as const,
    savedAt: schedule.savedAt.toISOString(),
    updatedAt: schedule.updatedAt.toISOString(),
    deletedAt: schedule.deletedAt?.toISOString(),
  };
}

function toNotificationAlert(alert: typeof notificationAlertSubscriptions.$inferSelect) {
  return {
    id: alert.id,
    topicKind: alert.topicKind,
    topicId: alert.topicId,
    label: alert.label,
    daysOfWeek: alert.daysOfWeek,
    windows: alert.windows,
    minimumSeverity: alert.minimumSeverity,
    enabled: alert.enabled,
    savedAt: alert.savedAt.toISOString(),
    updatedAt: alert.updatedAt.toISOString(),
    deletedAt: alert.deletedAt?.toISOString(),
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
