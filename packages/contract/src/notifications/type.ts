import * as z from 'zod';

import {
  apnsEnvironmentSchema,
  apnsTokenSchema,
  activeJourneyRegistrationSchema,
  activeJourneyUnregistrationSchema,
  notificationAlertSubscriptionSchema,
  notificationCategoryPreferenceSchema,
  notificationCategorySchema,
  notificationDeviceRegistrationSchema,
  notificationDeviceUnregistrationSchema,
  notificationDropReasonSchema,
  notificationInboxItemSchema,
  notificationInboxPageSchema,
  notificationInterruptionLevelSchema,
  notificationLocationSchema,
  notificationMuteInputSchema,
  notificationPreferencesSchema,
  notificationRegistrationResponseSchema,
  notificationRemovalResponseSchema,
  notificationScheduleSchema,
  notificationSeveritySchema,
  notificationSnoozeInputSchema,
  notificationTimeWindowSchema,
  notificationInboxQuerySchema,
  notificationMarkReadInputSchema,
} from './schema';

export type APNsEnvironment = z.infer<typeof apnsEnvironmentSchema>;
export type APNsToken = z.infer<typeof apnsTokenSchema>;
export type NotificationDeviceRegistration = z.infer<typeof notificationDeviceRegistrationSchema>;
export type NotificationDeviceUnregistration = z.infer<typeof notificationDeviceUnregistrationSchema>;
export type ActiveJourneyRegistration = z.infer<typeof activeJourneyRegistrationSchema>;
export type ActiveJourneyUnregistration = z.infer<typeof activeJourneyUnregistrationSchema>;
export type NotificationRegistrationResponse = z.infer<typeof notificationRegistrationResponseSchema>;
export type NotificationRemovalResponse = z.infer<typeof notificationRemovalResponseSchema>;
export type NotificationCategory = z.infer<typeof notificationCategorySchema>;
export type NotificationSeverity = z.infer<typeof notificationSeveritySchema>;
export type NotificationInterruptionLevel = z.infer<
  typeof notificationInterruptionLevelSchema
>;
export type NotificationDropReason = z.infer<typeof notificationDropReasonSchema>;
export type NotificationTimeWindow = z.infer<typeof notificationTimeWindowSchema>;
export type NotificationCategoryPreference = z.infer<
  typeof notificationCategoryPreferenceSchema
>;
export type NotificationPreferences = z.infer<typeof notificationPreferencesSchema>;
export type NotificationLocation = z.infer<typeof notificationLocationSchema>;
export type NotificationSchedule = z.infer<typeof notificationScheduleSchema>;
export type NotificationAlertSubscription = z.infer<
  typeof notificationAlertSubscriptionSchema
>;
export type NotificationInboxItem = z.infer<typeof notificationInboxItemSchema>;
export type NotificationInboxPage = z.infer<typeof notificationInboxPageSchema>;
export type NotificationInboxQuery = z.infer<typeof notificationInboxQuerySchema>;
export type NotificationMarkReadInput = z.infer<typeof notificationMarkReadInputSchema>;
export type NotificationSnoozeInput = z.infer<typeof notificationSnoozeInputSchema>;
export type NotificationMuteInput = z.infer<typeof notificationMuteInputSchema>;
