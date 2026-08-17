import * as z from 'zod';

import {
  accountDeleteInputSchema,
  accountDeleteResponseSchema,
  accountPlaceRoleSchema,
  accountPlaceSchema,
  accountRecentSearchSchema,
  accountSyncInputSchema,
  accountSyncOperationSchema,
  accountSyncResponseSchema,
  favoriteStationSchema,
  transportPreferencesSchema,
} from './schema';

export type FavoriteStation = z.infer<typeof favoriteStationSchema>;
export type AccountPlace = z.infer<typeof accountPlaceSchema>;
export type AccountPlaceRole = z.infer<typeof accountPlaceRoleSchema>;
export type AccountRecentSearch = z.infer<typeof accountRecentSearchSchema>;
export type TransportPreferences = z.infer<typeof transportPreferencesSchema>;
export type AccountSyncOperation = z.infer<typeof accountSyncOperationSchema>;
export type AccountSyncInput = z.infer<typeof accountSyncInputSchema>;
export type AccountSyncResponse = z.infer<typeof accountSyncResponseSchema>;
export type AccountDeleteInput = z.infer<typeof accountDeleteInputSchema>;
export type AccountDeleteResponse = z.infer<typeof accountDeleteResponseSchema>;
