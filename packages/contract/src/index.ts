import { departuresForStationRelation } from './departures';
import { healthRelation } from './health';
import { networkMapRelation } from './network';
import { searchQueryRelation } from './search';

export const contract = {
  departures: {
    forStation: departuresForStationRelation,
  },
  health: healthRelation,
  network: {
    map: networkMapRelation,
  },
  search: {
    query: searchQueryRelation,
  },
};

export * from './departures/schema';
export * from './departures/type';
export * from './health/schema';
export * from './health/type';
export * from './network/schema';
export * from './network/type';
export * from './search/schema';
export * from './search/type';
export * from './shared';
