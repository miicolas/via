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

export const accountSyncOperationSchema = z
  .object({
    operationId: z.uuid(),
    kind: z.enum([
      'favorite.upsert',
      'favorite.remove',
      'recent.upsert',
      'recent.remove',
      'recent.clear',
      'preferences.set',
      'place.upsert',
      'place.remove',
      'destination.upsert',
      'destination.remove',
      'notifications.preferences.set',
      'notifications.schedule.upsert',
      'notifications.schedule.remove',
      'notifications.alert.upsert',
      'notifications.alert.remove',
    ]),
    occurredAt: z.iso.datetime({ offset: true }),
    station: favoriteStationSchema.optional(),
    stationId: z.string().min(1).max(300).optional(),
    recentId: z.string().min(1).max(500).optional(),
    recent: accountRecentSearchSchema.optional(),
    preferences: transportPreferencesSchema.optional(),
    place: accountPlaceSchema.optional(),
    placeId: z.string().min(1).max(500).optional(),
    destination: savedDestinationSchema.optional(),
    destinationId: z.uuid().optional(),
    notificationPreferences: notificationPreferencesSchema.optional(),
    schedule: notificationScheduleSchema.optional(),
    scheduleId: z.string().min(1).max(128).optional(),
    alertSubscription: notificationAlertSubscriptionSchema.optional(),
    alertSubscriptionId: z.string().min(1).max(128).optional(),
  })
  .superRefine((operation, context) => {
    const valid =
      (operation.kind === 'favorite.upsert' && operation.station !== undefined) ||
      (operation.kind === 'favorite.remove' && operation.stationId !== undefined) ||
      (operation.kind === 'recent.upsert' && operation.recent !== undefined) ||
      (operation.kind === 'recent.remove' && operation.recentId !== undefined) ||
      operation.kind === 'recent.clear' ||
      (operation.kind === 'preferences.set' && operation.preferences !== undefined) ||
      (operation.kind === 'place.upsert' && operation.place !== undefined) ||
      (operation.kind === 'place.remove' && operation.placeId !== undefined) ||
      (operation.kind === 'destination.upsert' && operation.destination !== undefined) ||
      (operation.kind === 'destination.remove' && operation.destinationId !== undefined) ||
      (operation.kind === 'notifications.preferences.set' &&
        operation.notificationPreferences !== undefined) ||
      (operation.kind === 'notifications.schedule.upsert' &&
        operation.schedule !== undefined) ||
      (operation.kind === 'notifications.schedule.remove' &&
        operation.scheduleId !== undefined) ||
      (operation.kind === 'notifications.alert.upsert' &&
        operation.alertSubscription !== undefined) ||
      (operation.kind === 'notifications.alert.remove' &&
        operation.alertSubscriptionId !== undefined);

    if (!valid) {
      context.addIssue({
        code: 'custom',
        message: `Payload absent pour l’opération ${operation.kind}`,
      });
    }
  });

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
