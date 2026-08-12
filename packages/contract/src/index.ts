import { healthRelation } from './health';
import { networkMapRelation } from './network';
import { searchQueryRelation } from './search';

export const contract = {
  health: healthRelation,
  network: {
    map: networkMapRelation,
  },
  search: {
    query: searchQueryRelation,
  },
};

export * from './health/schema';
export * from './health/type';
export * from './network/schema';
export * from './network/type';
export * from './search/schema';
export * from './search/type';
export * from './shared';
