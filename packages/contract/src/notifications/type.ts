import * as z from 'zod';

import {
  apnsEnvironmentSchema,
  apnsTokenSchema,
  activeJourneyRegistrationSchema,
  activeJourneyUnregistrationSchema,
  notificationDeviceRegistrationSchema,
  notificationDeviceUnregistrationSchema,
  notificationRegistrationResponseSchema,
  notificationRemovalResponseSchema,
} from './schema';

export type APNsEnvironment = z.infer<typeof apnsEnvironmentSchema>;
export type APNsToken = z.infer<typeof apnsTokenSchema>;
export type NotificationDeviceRegistration = z.infer<typeof notificationDeviceRegistrationSchema>;
export type NotificationDeviceUnregistration = z.infer<typeof notificationDeviceUnregistrationSchema>;
export type ActiveJourneyRegistration = z.infer<typeof activeJourneyRegistrationSchema>;
export type ActiveJourneyUnregistration = z.infer<typeof activeJourneyUnregistrationSchema>;
export type NotificationRegistrationResponse = z.infer<typeof notificationRegistrationResponseSchema>;
export type NotificationRemovalResponse = z.infer<typeof notificationRemovalResponseSchema>;
