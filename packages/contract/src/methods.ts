/**
 * RPC transport methods, mirrored from each relation's `.route()`. Kept
 * zod-free so app bundles can import it without pulling the schemas in;
 * `methods.test.ts` pins it to the relations, so a renamed router or a new
 * POST procedure fails the contract tests instead of silently going out as a
 * cacheable GET.
 */
const POST_PROCEDURES = new Set([
  "account.delete",
  "account.sync",
  "friends.createInvitation",
  "friends.acceptInvitation",
  "friends.remove",
  "naturalJourneys.submit",
  "journeys.departureChoices",
  "journeyShares.create",
  "meetups.create",
  "meetups.update",
  "meetups.cancel",
  "meetups.createInvitation",
  "meetups.acceptInvitation",
  "meetups.declineInvitation",
  "meetups.revokeInvitation",
  "meetups.configureParticipant",
  "meetups.leave",
  "meetups.removeParticipant",
  "meetups.publishLive",
  "meetups.registerDeviceKey",
  "meetups.uploadKeyEnvelopes",
  "meetups.registerActivity",
  "meetups.unregisterActivity",
  "notifications.registerDevice",
  "notifications.unregisterDevice",
  "notifications.registerActivity",
  "notifications.unregisterActivity",
  "notifications.registerPushToStart",
  "notifications.registerActiveJourney",
  "notifications.unregisterActiveJourney",
  "notifications.markInboxRead",
  "notifications.snooze",
  "notifications.mute",
  "reports.submit",
]);

export function rpcMethod(path: readonly string[]): "GET" | "POST" {
  return POST_PROCEDURES.has(path.join(".")) ? "POST" : "GET";
}
