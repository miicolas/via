import { and, asc, desc, eq, isNull, sql } from 'drizzle-orm';
import type { PgColumn, PgTable } from 'drizzle-orm/pg-core';
import {
  accountFavoriteStations,
  accountPlaces,
  accountRecentSearches,
  accountSavedDestinations,
  accountSyncOperations,
  db,
  notificationAlertSubscriptions,
  notificationPreferences,
  notificationSchedules,
  users,
} from '@via/db';
import {
  ACCOUNT_FAVORITE_LIMIT,
  ACCOUNT_SAVED_DESTINATION_LIMIT,
  NOTIFICATION_ALERT_LIMIT,
  NOTIFICATION_SCHEDULE_LIMIT,
  ACCOUNT_RECENT_LIMIT,
  networkModeSchema,
  type NetworkMode,
  type AccountSyncInput,
  type AccountSyncResponse,
} from '@via/contract';
import {
  defaultNotificationPreferences,
  mergeNotificationPreferences,
} from '../../notifications/preferences';
import { applyAccountSyncOperation } from './sync-appliers';

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
      await applyAccountSyncOperation({ transaction, userId }, operation);
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
      table: accountSavedDestinations,
      idColumn: accountSavedDestinations.id,
      savedAtColumn: accountSavedDestinations.savedAt,
      userIdColumn: accountSavedDestinations.userId,
      limit: ACCOUNT_SAVED_DESTINATION_LIMIT,
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

  const [favorites, recents, places, destinations, preferences, storedNotificationPreferences, schedules, alerts] = await Promise.all([
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
      .select()
      .from(accountSavedDestinations)
      .where(eq(accountSavedDestinations.userId, userId))
      .orderBy(asc(accountSavedDestinations.position), asc(accountSavedDestinations.id)),
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
      systemImage: place.systemImage,
      savedAt: place.savedAt.toISOString(),
      updatedAt: place.updatedAt.toISOString(),
    })),
    destinations: destinations.map((destination) => ({
      id: destination.id,
      destinationId: destination.destinationId,
      kind: destination.kind,
      name: destination.name,
      context: destination.context ?? undefined,
      coordinate: { latitude: destination.latitude, longitude: destination.longitude },
      label: destination.label,
      systemImage: destination.systemImage,
      position: destination.position,
      savedAt: destination.savedAt.toISOString(),
      updatedAt: destination.updatedAt.toISOString(),
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
    networkModeSchema.safeParse(mode).success
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
