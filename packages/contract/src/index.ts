import { departuresForStationRelation } from './departures';
import { healthRelation } from './health';
import { journeysPlanRelation } from './journeys';
import { naturalJourneysSubmitRelation } from './natural-journeys';
import { railMapRelation, stationsInAreaRelation } from './network';
import { searchQueryRelation } from './search';

export const contract = {
  departures: {
    forStation: departuresForStationRelation,
  },
  health: healthRelation,
  journeys: {
    plan: journeysPlanRelation,
  },
  naturalJourneys: {
    submit: naturalJourneysSubmitRelation,
  },
  network: {
    railMap: railMapRelation,
    stationsInArea: stationsInAreaRelation,
  },
  search: {
    query: searchQueryRelation,
  },
};

export * from './departures/schema';
export * from './departures/type';
export * from './health/schema';
export * from './health/type';
export * from './journeys/schema';
export * from './journeys/type';
export * from './natural-journeys/schema';
export * from './natural-journeys/type';
export * from './network/schema';
export * from './network/type';
export * from './search/schema';
export * from './search/type';
export * from './shared';
