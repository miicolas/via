import { accountDeleteRelation, accountSyncRelation } from './account';
import { departuresForStationRelation } from './departures';
import { healthRelation } from './health';
import { journeysPlanRelation } from './journeys';
import { lineDetailRelation, lineSearchRelation, lineStatusesRelation } from './lines';
import { naturalJourneysSubmitRelation } from './natural-journeys';
import { railMapRelation, stationsInAreaRelation } from './network';
import {
  notificationsRegisterActivityRelation,
  notificationsRegisterActiveJourneyRelation,
  notificationsRegisterDeviceRelation,
  notificationsRegisterPushToStartRelation,
  notificationsUnregisterActivityRelation,
  notificationsUnregisterActiveJourneyRelation,
  notificationsUnregisterDeviceRelation,
} from './notifications';
import { searchQueryRelation } from './search';

export const contract = {
  account: {
    delete: accountDeleteRelation,
    sync: accountSyncRelation,
  },
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
  notifications: {
    registerDevice: notificationsRegisterDeviceRelation,
    unregisterDevice: notificationsUnregisterDeviceRelation,
    registerActivity: notificationsRegisterActivityRelation,
    unregisterActivity: notificationsUnregisterActivityRelation,
    registerPushToStart: notificationsRegisterPushToStartRelation,
    registerActiveJourney: notificationsRegisterActiveJourneyRelation,
    unregisterActiveJourney: notificationsUnregisterActiveJourneyRelation,
  },
  lines: {
    statuses: lineStatusesRelation,
    search: lineSearchRelation,
    detail: lineDetailRelation,
  },
  network: {
    railMap: railMapRelation,
    stationsInArea: stationsInAreaRelation,
  },
  search: {
    query: searchQueryRelation,
  },
};

export * from './account';
export * from './departures/schema';
export * from './departures/type';
export * from './health/schema';
export * from './health/type';
export * from './journeys/schema';
export * from './journeys/type';
export * from './lines/schema';
export * from './lines/type';
export * from './natural-journeys/schema';
export * from './natural-journeys/type';
export * from './notifications';
export * from './network/schema';
export * from './network/type';
export * from './search/schema';
export * from './search/type';
export * from './shared';
