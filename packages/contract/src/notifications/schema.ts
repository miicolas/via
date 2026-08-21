import * as z from "zod";

/** APNs has separate endpoints for development and production tokens. */
export const apnsEnvironmentSchema = z.enum(["sandbox", "production"]);

/**
 * Device and ActivityKit tokens are opaque hexadecimal values issued by
 * Apple. Keeping the validation here prevents accidentally persisting a
 * bearer token, a base64 value, or an unbounded request body.
 */
export const apnsTokenSchema = z
  .string()
  .regex(/^[0-9a-f]+$/i, "Le token APNs doit être hexadécimal")
  .min(32)
  .max(512);

export const notificationInstallationIDSchema = z.uuid();

export const notificationAppMetadataSchema = z.object({
  bundleId: z
    .string()
    .regex(/^[A-Za-z0-9.-]+$/)
    .min(1)
    .max(255),
  environment: apnsEnvironmentSchema,
  appVersion: z.string().min(1).max(64).optional(),
  osVersion: z.string().min(1).max(64).optional(),
});

export const notificationDeviceRegistrationSchema = z
  .object({
    installationId: notificationInstallationIDSchema,
    deviceToken: apnsTokenSchema,
  })
  .extend(notificationAppMetadataSchema.shape);

export const notificationDeviceUnregistrationSchema = z.object({
  installationId: notificationInstallationIDSchema,
});

export const liveActivityRegistrationSchema = z
  .object({
    installationId: notificationInstallationIDSchema,
    activityId: z.string().min(1).max(128),
    journeyId: z.string().min(1).max(500),
    activityToken: apnsTokenSchema,
  })
  .extend(notificationAppMetadataSchema.shape);

export const liveActivityUnregistrationSchema = z.object({
  activityId: z.string().min(1).max(128),
});

export const liveActivityPushToStartRegistrationSchema = z
  .object({
    installationId: notificationInstallationIDSchema,
    pushToStartToken: apnsTokenSchema,
  })
  .extend(notificationAppMetadataSchema.shape);

/** The one journey whose line disruptions the installation wants remotely. */
export const activeJourneyRegistrationSchema = z
  .object({
    installationId: notificationInstallationIDSchema,
    journeyId: z.string().min(1).max(500),
    routeIds: z.array(z.string().min(1).max(255)).max(64),
    startsAt: z.iso.datetime({ offset: true }),
    endsAt: z.iso.datetime({ offset: true }),
  })
  .refine((value) => Date.parse(value.endsAt) > Date.parse(value.startsAt), {
    message: "La fenêtre du trajet doit se terminer après son début.",
    path: ["endsAt"],
  });

export const activeJourneyUnregistrationSchema = z.object({
  installationId: notificationInstallationIDSchema,
  journeyId: z.string().min(1).max(500),
});

export const notificationRegistrationResponseSchema = z.object({
  registered: z.literal(true),
});

export const notificationRemovalResponseSchema = z.object({
  removed: z.literal(true),
});
