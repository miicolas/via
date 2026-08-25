import { and, eq, isNull, lte, ne, or, sql } from 'drizzle-orm';
import {
  accountFavoriteStations,
  accountPlaces,
  accountRecentSearches,
  accountSavedDestinations,
  db,
  notificationAlertSubscriptions,
  notificationPreferences,
  notificationSchedules,
  users,
} from '@via/db';
import type { AccountSyncOperation } from '@via/contract';

type AccountSyncTransaction = Parameters<Parameters<typeof db.transaction>[0]>[0];
type OperationKind = AccountSyncOperation['kind'];
type OperationOf<Kind extends OperationKind> = Extract<AccountSyncOperation, { kind: Kind }>;

export type AccountSyncContext = {
  transaction: AccountSyncTransaction;
  userId: string;
};

type AccountSyncApplier<Kind extends OperationKind> = (
  context: AccountSyncContext,
  operation: OperationOf<Kind>,
) => Promise<void>;

type AccountSyncApplierRegistry = {
  [Kind in OperationKind]: AccountSyncApplier<Kind>;
};

/**
 * Each command owns only its table-specific mapping. The sync driver keeps
 * idempotency and retention outside this registry, so every new command gets
 * the same operation semantics before it can touch account state.
 */
const accountSyncAppliers: AccountSyncApplierRegistry = {
  'favorite.upsert': async ({ transaction, userId }, operation) => {
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
  },

  'favorite.remove': async ({ transaction, userId }, operation) => {
    await transaction
      .delete(accountFavoriteStations)
      .where(
        and(
          eq(accountFavoriteStations.userId, userId),
          eq(accountFavoriteStations.stationId, operation.stationId),
          lte(accountFavoriteStations.updatedAt, new Date(operation.occurredAt)),
        ),
      );
  },

  'recent.upsert': async ({ transaction, userId }, operation) => {
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
  },

  'recent.remove': async ({ transaction, userId }, operation) => {
    await transaction
      .delete(accountRecentSearches)
      .where(
        and(
          eq(accountRecentSearches.userId, userId),
          eq(accountRecentSearches.id, operation.recentId),
          lte(accountRecentSearches.savedAt, new Date(operation.occurredAt)),
        ),
      );
  },

  'recent.clear': async ({ transaction, userId }, operation) => {
    await transaction
      .delete(accountRecentSearches)
      .where(
        and(
          eq(accountRecentSearches.userId, userId),
          lte(accountRecentSearches.savedAt, new Date(operation.occurredAt)),
        ),
      );
  },

  'place.upsert': async ({ transaction, userId }, operation) => {
    const place = operation.place;
    await transaction
      .delete(accountSavedDestinations)
      .where(
        and(
          eq(accountSavedDestinations.userId, userId),
          eq(accountSavedDestinations.destinationId, place.id),
        ),
      );
    // Home and work are unique per user: reassigning the role evicts the
    // previous holder, last writer wins on `updatedAt`.
    await transaction
      .delete(accountPlaces)
      .where(
        and(
          eq(accountPlaces.userId, userId),
          eq(accountPlaces.role, place.role),
          ne(accountPlaces.id, place.id),
          lte(accountPlaces.updatedAt, new Date(place.updatedAt)),
        ),
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
        systemImage:
          place.systemImage ?? (place.role === 'home' ? 'house.fill' : 'briefcase.fill'),
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
          systemImage:
            place.systemImage ?? (place.role === 'home' ? 'house.fill' : 'briefcase.fill'),
          savedAt: new Date(place.savedAt),
          updatedAt: new Date(place.updatedAt),
        },
        setWhere: lte(accountPlaces.updatedAt, new Date(place.updatedAt)),
      });
  },

  'place.remove': async ({ transaction, userId }, operation) => {
    await transaction
      .delete(accountPlaces)
      .where(
        and(
          eq(accountPlaces.userId, userId),
          eq(accountPlaces.id, operation.placeId),
          lte(accountPlaces.updatedAt, new Date(operation.occurredAt)),
        ),
      );
  },

  'destination.upsert': async ({ transaction, userId }, operation) => {
    const destination = operation.destination;
    const pinned = await transaction
      .select({ id: accountPlaces.id })
      .from(accountPlaces)
      .where(
        and(
          eq(accountPlaces.userId, userId),
          eq(accountPlaces.id, destination.destinationId),
        ),
      )
      .limit(1);
    if (pinned.length > 0) return;

    const duplicate = await transaction
      .select({
        id: accountSavedDestinations.id,
        updatedAt: accountSavedDestinations.updatedAt,
      })
      .from(accountSavedDestinations)
      .where(
        and(
          eq(accountSavedDestinations.userId, userId),
          eq(accountSavedDestinations.destinationId, destination.destinationId),
          ne(accountSavedDestinations.id, destination.id),
        ),
      )
      .limit(1);
    if (duplicate[0]?.updatedAt && duplicate[0].updatedAt > new Date(destination.updatedAt)) {
      return;
    }
    if (duplicate[0]) {
      await transaction
        .delete(accountSavedDestinations)
        .where(
          and(
            eq(accountSavedDestinations.userId, userId),
            eq(accountSavedDestinations.id, duplicate[0].id),
          ),
        );
    }

    await transaction
      .insert(accountSavedDestinations)
      .values({
        userId,
        id: destination.id,
        destinationId: destination.destinationId,
        kind: destination.kind,
        name: destination.name,
        context: destination.context ?? null,
        latitude: destination.coordinate.latitude,
        longitude: destination.coordinate.longitude,
        label: destination.label,
        systemImage: destination.systemImage,
        position: destination.position,
        savedAt: new Date(destination.savedAt),
        updatedAt: new Date(destination.updatedAt),
      })
      .onConflictDoUpdate({
        target: [accountSavedDestinations.userId, accountSavedDestinations.id],
        set: {
          destinationId: destination.destinationId,
          kind: destination.kind,
          name: destination.name,
          context: destination.context ?? null,
          latitude: destination.coordinate.latitude,
          longitude: destination.coordinate.longitude,
          label: destination.label,
          systemImage: destination.systemImage,
          position: destination.position,
          savedAt: new Date(destination.savedAt),
          updatedAt: new Date(destination.updatedAt),
        },
        setWhere: lte(
          accountSavedDestinations.updatedAt,
          new Date(destination.updatedAt),
        ),
      });
  },

  'destination.remove': async ({ transaction, userId }, operation) => {
    await transaction
      .delete(accountSavedDestinations)
      .where(
        and(
          eq(accountSavedDestinations.userId, userId),
          eq(accountSavedDestinations.id, operation.destinationId),
          lte(accountSavedDestinations.updatedAt, new Date(operation.occurredAt)),
        ),
      );
  },

  'preferences.set': async ({ transaction, userId }, operation) => {
    const preferences = operation.preferences;
    // Preferences live as Better Auth `additionalFields` on the user row;
    // last writer wins on `preferencesUpdatedAt`.
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
            lte(users.preferencesUpdatedAt, new Date(preferences.updatedAt)),
          ),
        ),
      );
  },

  'notifications.preferences.set': async ({ transaction, userId }, operation) => {
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
  },

  'notifications.schedule.upsert': async ({ transaction, userId }, operation) => {
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
  },

  'notifications.schedule.remove': async ({ transaction, userId }, operation) => {
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
  },

  'notifications.alert.upsert': async ({ transaction, userId }, operation) => {
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
  },

  'notifications.alert.remove': async ({ transaction, userId }, operation) => {
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
  },
};

/** Dispatches a structurally narrowed operation to its table-specific applier. */
export async function applyAccountSyncOperation(
  context: AccountSyncContext,
  operation: AccountSyncOperation,
) {
  const applier = accountSyncAppliers[operation.kind] as (
    context: AccountSyncContext,
    operation: AccountSyncOperation,
  ) => Promise<void>;
  await applier(context, operation);
}
