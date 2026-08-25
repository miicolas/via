import { accountDeleteRelation, accountSyncRelation } from './account';
import { departuresForStationRelation } from './departures';
import { healthRelation } from './health';
import { journeyDepartureChoicesRelation, journeysPlanRelation } from './journeys';
import { lineDetailRelation, lineSearchRelation, lineStatusesRelation } from './lines';
import { naturalJourneysSubmitRelation } from './natural-journeys';
import { bikeStationsInAreaRelation, railMapRelation, stationsInAreaRelation } from './network';
import {
  notificationsRegisterActivityRelation,
  notificationsRegisterActiveJourneyRelation,
  notificationsRegisterDeviceRelation,
  notificationsRegisterPushToStartRelation,
  notificationsUnregisterActivityRelation,
  notificationsUnregisterActiveJourneyRelation,
  notificationsUnregisterDeviceRelation,
  notificationsInboxRelation,
  notificationsMarkInboxReadRelation,
  notificationsSnoozeRelation,
  notificationsMuteRelation,
} from './notifications';
import { searchQueryRelation } from './search';
import { reportSubmitRelation, stationStatusRelation } from './reports/relation';

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
    departureChoices: journeyDepartureChoicesRelation,
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
    inbox: notificationsInboxRelation,
    markInboxRead: notificationsMarkInboxReadRelation,
    snooze: notificationsSnoozeRelation,
    mute: notificationsMuteRelation,
  },
  lines: {
    statuses: lineStatusesRelation,
    search: lineSearchRelation,
    detail: lineDetailRelation,
  },
  network: {
    railMap: railMapRelation,
    stationsInArea: stationsInAreaRelation,
    bikeStationsInArea: bikeStationsInAreaRelation,
  },
  search: {
    query: searchQueryRelation,
  },
  reports: {
    submit: reportSubmitRelation,
    stationStatus: stationStatusRelation,
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
export { RAIL_MAP_PATH, RAIL_MAP_RPC_PATH } from './network/rail-map-relation';
export * from './search/schema';
export * from './search/type';
export * from './reports/schema';
export * from './reports/type';
export * from './shared';
