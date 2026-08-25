import * as z from 'zod';

import { coordinateSchema, networkModeSchema } from '../shared/schema';
import {
  NOTIFICATION_ALERT_LIMIT,
  NOTIFICATION_SCHEDULE_LIMIT,
  notificationAlertSubscriptionSchema,
  notificationPreferencesSchema,
  notificationScheduleSchema,
} from '../notifications/schema';

export const ACCOUNT_FAVORITE_LIMIT = 50;
export const ACCOUNT_RECENT_LIMIT = 5;
export const ACCOUNT_PLACE_LIMIT = 50;
export const ACCOUNT_SAVED_DESTINATION_LIMIT = 50;

export const favoriteStationSchema = z.object({
  stationId: z.string().min(1).max(300),
  name: z.string().min(1).max(300),
  coordinate: coordinateSchema.optional(),
  savedAt: z.iso.datetime({ offset: true }),
  updatedAt: z.iso.datetime({ offset: true }),
});

/** Favorite stations live in their own list; a place is a home or work slot. */
export const accountPlaceRoleSchema = z.enum(['home', 'work']);

export const accountPlaceSchema = z.object({
  id: z.string().min(1).max(500),
  kind: z.enum(['station', 'address']),
  name: z.string().min(1).max(300),
  context: z.string().max(500).optional(),
  coordinate: coordinateSchema,
  role: accountPlaceRoleSchema,
  systemImage: z.string().min(1).max(100).optional(),
  savedAt: z.iso.datetime({ offset: true }),
  updatedAt: z.iso.datetime({ offset: true }),
});

export const savedDestinationSchema = z.object({
  id: z.uuid(),
  destinationId: z.string().min(1).max(500),
  kind: z.enum(['station', 'address']),
  name: z.string().min(1).max(300),
  context: z.string().max(500).optional(),
  coordinate: coordinateSchema,
  label: z.string().trim().min(1).max(80),
  systemImage: z.string().min(1).max(100),
  position: z.number().int().min(0).max(ACCOUNT_SAVED_DESTINATION_LIMIT - 1),
  savedAt: z.iso.datetime({ offset: true }),
  updatedAt: z.iso.datetime({ offset: true }),
});

export const accountRecentSearchSchema = z.object({
  id: z.string().min(1).max(500),
  kind: z.enum(['station', 'address']),
  name: z.string().min(1).max(300),
  context: z.string().max(500).optional(),
  coordinate: coordinateSchema,
  savedAt: z.iso.datetime({ offset: true }),
});

export const transportPreferencesSchema = z.object({
  preferredModes: z.array(networkModeSchema).max(5),
  excludedModes: z.array(networkModeSchema).max(5),
  updatedAt: z.iso.datetime({ offset: true }),
});

const accountSyncOperationBaseSchema = z.object({
  operationId: z.uuid(),
  occurredAt: z.iso.datetime({ offset: true }),
});

/**
 * Each operation carries exactly the payload its command can apply. Keeping
 * the command and payload together gives API handlers a typed state machine:
 * a newly added operation cannot compile until both its contract branch and
 * its applier are present.
 */
export const accountSyncOperationSchema = z.discriminatedUnion('kind', [
  accountSyncOperationBaseSchema.extend({
    kind: z.literal('favorite.upsert'),
    station: favoriteStationSchema,
  }),
  accountSyncOperationBaseSchema.extend({
    kind: z.literal('favorite.remove'),
    stationId: z.string().min(1).max(300),
  }),
  accountSyncOperationBaseSchema.extend({
    kind: z.literal('recent.upsert'),
    recent: accountRecentSearchSchema,
  }),
  accountSyncOperationBaseSchema.extend({
    kind: z.literal('recent.remove'),
    recentId: z.string().min(1).max(500),
  }),
  accountSyncOperationBaseSchema.extend({
    kind: z.literal('recent.clear'),
  }),
  accountSyncOperationBaseSchema.extend({
    kind: z.literal('preferences.set'),
    preferences: transportPreferencesSchema,
  }),
  accountSyncOperationBaseSchema.extend({
    kind: z.literal('place.upsert'),
    place: accountPlaceSchema,
  }),
  accountSyncOperationBaseSchema.extend({
    kind: z.literal('place.remove'),
    placeId: z.string().min(1).max(500),
  }),
  accountSyncOperationBaseSchema.extend({
    kind: z.literal('destination.upsert'),
    destination: savedDestinationSchema,
  }),
  accountSyncOperationBaseSchema.extend({
    kind: z.literal('destination.remove'),
    destinationId: z.uuid(),
  }),
  accountSyncOperationBaseSchema.extend({
    kind: z.literal('notifications.preferences.set'),
    notificationPreferences: notificationPreferencesSchema,
  }),
  accountSyncOperationBaseSchema.extend({
    kind: z.literal('notifications.schedule.upsert'),
    schedule: notificationScheduleSchema,
  }),
  accountSyncOperationBaseSchema.extend({
    kind: z.literal('notifications.schedule.remove'),
    scheduleId: z.string().min(1).max(128),
  }),
  accountSyncOperationBaseSchema.extend({
    kind: z.literal('notifications.alert.upsert'),
    alertSubscription: notificationAlertSubscriptionSchema,
  }),
  accountSyncOperationBaseSchema.extend({
    kind: z.literal('notifications.alert.remove'),
    alertSubscriptionId: z.string().min(1).max(128),
  }),
]);

export const accountSyncInputSchema = z.object({
  operations: z.array(accountSyncOperationSchema).max(100),
});

export const accountSyncResponseSchema = z.object({
  appliedOperationIds: z.array(z.uuid()),
  favorites: z.array(favoriteStationSchema).max(ACCOUNT_FAVORITE_LIMIT),
  recents: z.array(accountRecentSearchSchema).max(ACCOUNT_RECENT_LIMIT),
  places: z.array(accountPlaceSchema).max(ACCOUNT_PLACE_LIMIT),
  destinations: z.array(savedDestinationSchema).max(ACCOUNT_SAVED_DESTINATION_LIMIT).optional(),
  preferences: transportPreferencesSchema,
  notificationPreferences: notificationPreferencesSchema,
  notificationSchedules: z.array(notificationScheduleSchema).max(NOTIFICATION_SCHEDULE_LIMIT),
  notificationAlerts: z.array(notificationAlertSubscriptionSchema).max(NOTIFICATION_ALERT_LIMIT),
  syncedAt: z.iso.datetime({ offset: true }),
});

export const accountDeleteInputSchema = z.object({
  identityToken: z.string().min(1),
  authorizationCode: z.string().min(1),
  nonce: z.string().min(16).max(256),
});

export const accountDeleteResponseSchema = z.object({ deleted: z.literal(true) });
