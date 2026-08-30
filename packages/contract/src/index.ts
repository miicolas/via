import { accountDeleteRelation, accountSyncRelation } from "./account";
import { departuresForStationRelation } from "./departures";
import { healthRelation } from "./health";
import {
  friendInvitationAcceptRelation,
  friendInvitationCreateRelation,
  friendInvitationPreviewRelation,
  friendRemoveRelation,
  friendsListRelation,
} from "./friends";
import {
  journeyShareCreateRelation,
  journeyShareGetRelation,
} from "./journey-shares";
import {
  journeyDepartureChoicesRelation,
  journeysPlanRelation,
} from "./journeys";
import {
  lineDetailRelation,
  lineSearchRelation,
  lineStatusesRelation,
} from "./lines";
import {
  meetupCancelRelation,
  meetupCreateRelation,
  meetupGetRelation,
  meetupInvitationAcceptRelation,
  meetupInvitationCreateRelation,
  meetupInvitationDeclineRelation,
  meetupInvitationPreviewRelation,
  meetupInvitationRevokeRelation,
  meetupLeaveRelation,
  meetupListRelation,
  meetupLivePollRelation,
  meetupLivePublishRelation,
  meetupParticipantConfigureRelation,
  meetupRegisterActivityRelation,
  meetupRegisterDeviceKeyRelation,
  meetupRemoveParticipantRelation,
  meetupSyncKeysRelation,
  meetupUnregisterActivityRelation,
  meetupUpdateRelation,
  meetupUploadKeyEnvelopesRelation,
} from "./meetups";
import { naturalJourneysSubmitRelation } from "./natural-journeys";
import {
  bikeStationsInAreaRelation,
  railMapRelation,
  sharedMobilityInAreaRelation,
  stationCrowdingRelation,
  stationsInAreaRelation,
} from "./network";
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
} from "./notifications";
import { searchQueryRelation } from "./search";
import {
  reportSubmitRelation,
  stationStatusRelation,
} from "./reports/relation";

export const contract = {
  account: {
    delete: accountDeleteRelation,
    sync: accountSyncRelation,
  },
  departures: {
    forStation: departuresForStationRelation,
  },
  health: healthRelation,
  friends: {
    list: friendsListRelation,
    createInvitation: friendInvitationCreateRelation,
    previewInvitation: friendInvitationPreviewRelation,
    acceptInvitation: friendInvitationAcceptRelation,
    remove: friendRemoveRelation,
  },
  journeys: {
    plan: journeysPlanRelation,
    departureChoices: journeyDepartureChoicesRelation,
  },
  journeyShares: {
    create: journeyShareCreateRelation,
    get: journeyShareGetRelation,
  },
  meetups: {
    create: meetupCreateRelation,
    list: meetupListRelation,
    get: meetupGetRelation,
    update: meetupUpdateRelation,
    cancel: meetupCancelRelation,
    createInvitation: meetupInvitationCreateRelation,
    previewInvitation: meetupInvitationPreviewRelation,
    acceptInvitation: meetupInvitationAcceptRelation,
    declineInvitation: meetupInvitationDeclineRelation,
    revokeInvitation: meetupInvitationRevokeRelation,
    configureParticipant: meetupParticipantConfigureRelation,
    leave: meetupLeaveRelation,
    removeParticipant: meetupRemoveParticipantRelation,
    publishLive: meetupLivePublishRelation,
    pollLive: meetupLivePollRelation,
    registerDeviceKey: meetupRegisterDeviceKeyRelation,
    uploadKeyEnvelopes: meetupUploadKeyEnvelopesRelation,
    syncKeys: meetupSyncKeysRelation,
    registerActivity: meetupRegisterActivityRelation,
    unregisterActivity: meetupUnregisterActivityRelation,
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
    sharedMobilityInArea: sharedMobilityInAreaRelation,
    stationCrowding: stationCrowdingRelation,
  },
  search: {
    query: searchQueryRelation,
  },
  reports: {
    submit: reportSubmitRelation,
    stationStatus: stationStatusRelation,
  },
};

export * from "./account";
export * from "./departures/schema";
export * from "./departures/type";
export * from "./health/schema";
export * from "./health/type";
export * from "./friends";
export * from "./journeys/schema";
export * from "./journeys/type";
export * from "./journey-shares";
export * from "./lines/schema";
export * from "./lines/type";
export * from "./meetups";
export * from "./natural-journeys/schema";
export * from "./natural-journeys/type";
export * from "./notifications";
export * from "./network/schema";
export * from "./network/type";
export { RAIL_MAP_PATH, RAIL_MAP_RPC_PATH } from "./network/rail-map-relation";
export * from "./search/schema";
export * from "./search/type";
export * from "./reports/schema";
export * from "./reports/type";
export * from "./shared";
