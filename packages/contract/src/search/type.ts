import * as z from 'zod';

import {
  addressSearchResultSchema,
  searchInputSchema,
  searchResponseSchema,
  searchResultSchema,
  stationSearchResultSchema,
} from './schema';

export type SearchInput = z.infer<typeof searchInputSchema>;
export type StationSearchResult = z.infer<typeof stationSearchResultSchema>;
export type AddressSearchResult = z.infer<typeof addressSearchResultSchema>;
export type SearchResult = z.infer<typeof searchResultSchema>;
export type SearchResponse = z.infer<typeof searchResponseSchema>;
