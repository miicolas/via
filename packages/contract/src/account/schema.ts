import * as z from 'zod';

import { coordinateSchema, networkModeSchema } from '../shared/schema';

export const ACCOUNT_FAVORITE_LIMIT = 50;
export const ACCOUNT_RECENT_LIMIT = 5;

export const favoriteStationSchema = z.object({
  stationId: z.string().min(1).max(300),
  name: z.string().min(1).max(300),
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
      'recent.clear',
      'preferences.set',
    ]),
    occurredAt: z.iso.datetime({ offset: true }),
    station: favoriteStationSchema.optional(),
    stationId: z.string().min(1).max(300).optional(),
    recent: accountRecentSearchSchema.optional(),
    preferences: transportPreferencesSchema.optional(),
  })
  .superRefine((operation, context) => {
    const valid =
      (operation.kind === 'favorite.upsert' && operation.station !== undefined) ||
      (operation.kind === 'favorite.remove' && operation.stationId !== undefined) ||
      (operation.kind === 'recent.upsert' && operation.recent !== undefined) ||
      operation.kind === 'recent.clear' ||
      (operation.kind === 'preferences.set' && operation.preferences !== undefined);

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
  preferences: transportPreferencesSchema,
  syncedAt: z.iso.datetime({ offset: true }),
});

export const accountDeleteInputSchema = z.object({
  identityToken: z.string().min(1),
  authorizationCode: z.string().min(1),
  nonce: z.string().min(16).max(256),
});

export const accountDeleteResponseSchema = z.object({ deleted: z.literal(true) });
