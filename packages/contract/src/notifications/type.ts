import * as z from "zod";

import {
  apnsEnvironmentSchema,
  apnsTokenSchema,
  activeJourneyRegistrationSchema,
  activeJourneyUnregistrationSchema,
  liveActivityPushToStartRegistrationSchema,
  liveActivityRegistrationSchema,
  liveActivityUnregistrationSchema,
  notificationDeviceRegistrationSchema,
  notificationDeviceUnregistrationSchema,
  notificationRegistrationResponseSchema,
  notificationRemovalResponseSchema,
} from "./schema";

export type APNsEnvironment = z.infer<typeof apnsEnvironmentSchema>;
export type APNsToken = z.infer<typeof apnsTokenSchema>;
export type NotificationDeviceRegistration = z.infer<
  typeof notificationDeviceRegistrationSchema
>;
export type NotificationDeviceUnregistration = z.infer<
  typeof notificationDeviceUnregistrationSchema
>;
export type LiveActivityRegistration = z.infer<
  typeof liveActivityRegistrationSchema
>;
export type LiveActivityUnregistration = z.infer<
  typeof liveActivityUnregistrationSchema
>;
export type LiveActivityPushToStartRegistration = z.infer<
  typeof liveActivityPushToStartRegistrationSchema
>;
export type ActiveJourneyRegistration = z.infer<
  typeof activeJourneyRegistrationSchema
>;
export type ActiveJourneyUnregistration = z.infer<
  typeof activeJourneyUnregistrationSchema
>;
export type NotificationRegistrationResponse = z.infer<
  typeof notificationRegistrationResponseSchema
>;
export type NotificationRemovalResponse = z.infer<
  typeof notificationRemovalResponseSchema
>;
