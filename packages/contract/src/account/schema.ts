import * as z from 'zod';

import { coordinateSchema, networkModeSchema } from '../shared/schema';

export const ACCOUNT_FAVORITE_LIMIT = 50;
export const ACCOUNT_RECENT_LIMIT = 5;
export const ACCOUNT_PLACE_LIMIT = 50;
/** Favorites get trimmed; home and work always keep their slot. */
export const ACCOUNT_PLACE_FAVORITE_LIMIT = ACCOUNT_PLACE_LIMIT - 2;

export const favoriteStationSchema = z.object({
  stationId: z.string().min(1).max(300),
  name: z.string().min(1).max(300),
  coordinate: coordinateSchema.optional(),
  savedAt: z.iso.datetime({ offset: true }),
  updatedAt: z.iso.datetime({ offset: true }),
});

export const accountPlaceRoleSchema = z.enum(['home', 'work', 'favorite']);

export const accountPlaceSchema = z.object({
  id: z.string().min(1).max(500),
  kind: z.enum(['station', 'address']),
  name: z.string().min(1).max(300),
  context: z.string().max(500).optional(),
  coordinate: coordinateSchema,
  role: accountPlaceRoleSchema,
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
    ]),
    occurredAt: z.iso.datetime({ offset: true }),
    station: favoriteStationSchema.optional(),
    stationId: z.string().min(1).max(300).optional(),
    recentId: z.string().min(1).max(500).optional(),
    recent: accountRecentSearchSchema.optional(),
    preferences: transportPreferencesSchema.optional(),
    place: accountPlaceSchema.optional(),
    placeId: z.string().min(1).max(500).optional(),
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
      (operation.kind === 'place.remove' && operation.placeId !== undefined);

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
  preferences: transportPreferencesSchema,
  syncedAt: z.iso.datetime({ offset: true }),
});

export const accountDeleteInputSchema = z.object({
  identityToken: z.string().min(1),
  authorizationCode: z.string().min(1),
  nonce: z.string().min(16).max(256),
});

export const accountDeleteResponseSchema = z.object({ deleted: z.literal(true) });
