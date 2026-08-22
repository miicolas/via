import * as z from 'zod';

export const NOTIFICATION_CATEGORIES = [
  'journey',
  'commute',
  'line',
  'station',
  'digest',
  'recommendation',
] as const;

export const NOTIFICATION_ALERT_LIMIT = 40;
export const NOTIFICATION_SCHEDULE_LIMIT = 20;

export const notificationCategorySchema = z.enum(NOTIFICATION_CATEGORIES);

/** The three severity values already used by the normalized PRIM feed. */
export const notificationSeveritySchema = z.enum([
  'attention',
  'disrupted',
  'suspended',
]);

export const notificationInterruptionLevelSchema = z.enum([
  'passive',
  'active',
  'timeSensitive',
  'critical',
]);

export const notificationDropReasonSchema = z.enum([
  'disabled',
  'quiet-hours',
  'cap',
  'category-off',
  'severity',
  'stale',
  'no-signal',
  'empty',
  'muted',
]);

export const notificationTimeWindowSchema = z
  .object({
    startMinute: z.number().int().min(0).max(1_439),
    endMinute: z.number().int().min(0).max(1_439),
  })
  .refine((value) => value.startMinute !== value.endMinute, {
    message: 'Une plage horaire doit avoir une durée non nulle.',
    path: ['endMinute'],
  });

export const notificationCategoryPreferenceSchema = z.object({
  category: notificationCategorySchema,
  enabled: z.boolean(),
  minimumSeverity: notificationSeveritySchema,
  dailyCap: z.number().int().min(0).max(100).optional(),
});

export const notificationPreferencesSchema = z
  .object({
    enabled: z.boolean(),
    timeZone: z.literal('Europe/Paris').default('Europe/Paris'),
    quietHoursStartMinute: z.number().int().min(0).max(1_439).optional(),
    quietHoursEndMinute: z.number().int().min(0).max(1_439).optional(),
    mutedOnWeekends: z.boolean(),
    mutedOnHolidays: z.boolean(),
    minimumSeverity: notificationSeveritySchema,
    dailyCap: z.number().int().min(0).max(100).optional(),
    categories: z.array(notificationCategoryPreferenceSchema).max(6),
    updatedAt: z.iso.datetime({ offset: true }),
  })
  .superRefine((value, context) => {
    const hasStart = value.quietHoursStartMinute !== undefined;
    const hasEnd = value.quietHoursEndMinute !== undefined;
    if (hasStart !== hasEnd) {
      context.addIssue({
        code: 'custom',
        message: 'Les heures calmes doivent avoir un début et une fin.',
        path: [hasStart ? 'quietHoursEndMinute' : 'quietHoursStartMinute'],
      });
    }
  });

export const notificationLocationSchema = z.object({
  id: z.string().min(1).max(500),
  kind: z.enum(['station', 'address']),
  name: z.string().min(1).max(300),
  context: z.string().max(500).optional(),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
});

export const notificationScheduleSchema = z.object({
  id: z.string().min(1).max(128),
  kind: z.enum(['commute', 'digest']),
  label: z.string().min(1).max(160),
  revision: z.number().int().min(1),
  origin: notificationLocationSchema.optional(),
  destination: notificationLocationSchema.optional(),
  routeIds: z.array(z.string().min(1).max(255)).max(64),
  daysOfWeek: z.array(z.number().int().min(0).max(6)).max(7),
  departureMinute: z.number().int().min(0).max(1_439),
  leadMinutes: z.number().int().min(0).max(240),
  skipHolidays: z.boolean(),
  enabled: z.boolean(),
  pausedUntil: z.iso.datetime({ offset: true }).optional(),
  timeZone: z.literal('Europe/Paris').default('Europe/Paris'),
  savedAt: z.iso.datetime({ offset: true }),
  updatedAt: z.iso.datetime({ offset: true }),
  deletedAt: z.iso.datetime({ offset: true }).optional(),
});

export const notificationAlertSubscriptionSchema = z.object({
  id: z.string().min(1).max(128),
  topicKind: z.enum(['line', 'station']),
  topicId: z.string().min(1).max(300),
  label: z.string().min(1).max(160),
  daysOfWeek: z.array(z.number().int().min(0).max(6)).max(7),
  windows: z.array(notificationTimeWindowSchema).max(8),
  minimumSeverity: notificationSeveritySchema,
  enabled: z.boolean(),
  savedAt: z.iso.datetime({ offset: true }),
  updatedAt: z.iso.datetime({ offset: true }),
  deletedAt: z.iso.datetime({ offset: true }).optional(),
});

export const notificationInboxItemSchema = z.object({
  id: z.string().min(1).max(128),
  occurrenceId: z.string().min(1).max(128).optional(),
  category: notificationCategorySchema,
  title: z.string().min(1).max(256),
  body: z.string().min(1).max(2_500),
  deepLink: z.string().max(1_024).optional(),
  topicKind: z.enum(['line', 'station']).optional(),
  topicId: z.string().max(300).optional(),
  severity: notificationSeveritySchema.optional(),
  dropReason: notificationDropReasonSchema.optional(),
  createdAt: z.iso.datetime({ offset: true }),
  readAt: z.iso.datetime({ offset: true }).optional(),
});

export const notificationInboxPageSchema = z.object({
  items: z.array(notificationInboxItemSchema).max(100),
  nextCursor: z.string().min(1).max(300).optional(),
  unreadCount: z.number().int().min(0),
});

export const notificationInboxQuerySchema = z.object({
  cursor: z.string().min(1).max(300).optional(),
  limit: z.number().int().min(1).max(100).default(50),
});

export const notificationMarkReadInputSchema = z.object({
  readBefore: z.iso.datetime({ offset: true }),
});

export const notificationSnoozeInputSchema = z.object({
  occurrenceId: z.string().min(1).max(128),
  until: z.iso.datetime({ offset: true }),
});

export const notificationMuteInputSchema = z.object({
  scope: z.enum(['category', 'topic']),
  key: z.string().min(1).max(300),
  mutedUntil: z.iso.datetime({ offset: true }).optional(),
});

/** APNs has separate endpoints for development and production tokens. */
export const apnsEnvironmentSchema = z.enum(['sandbox', 'production']);

/**
 * Device and ActivityKit tokens are opaque hexadecimal values issued by
 * Apple. Keeping the validation here prevents accidentally persisting a
 * bearer token, a base64 value, or an unbounded request body.
 */
export const apnsTokenSchema = z
  .string()
  .regex(/^[0-9a-f]+$/i, 'Le token APNs doit être hexadécimal')
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

/** @deprecated Compatibility input for iOS builds predating local-only Live Activities. */
export const liveActivityRegistrationSchema = z
  .object({
    installationId: notificationInstallationIDSchema,
    activityId: z.string().min(1).max(128),
    journeyId: z.string().min(1).max(500),
    activityToken: apnsTokenSchema,
  })
  .extend(notificationAppMetadataSchema.shape);

/** @deprecated Compatibility input for iOS builds predating local-only Live Activities. */
export const liveActivityUnregistrationSchema = z.object({
  activityId: z.string().min(1).max(128),
});

/** @deprecated Compatibility input for iOS builds predating local-only Live Activities. */
export const liveActivityPushToStartRegistrationSchema = z
  .object({
    installationId: notificationInstallationIDSchema,
    pushToStartToken: apnsTokenSchema,
  })
  .extend(notificationAppMetadataSchema.shape);

/** The one journey whose line disruptions the installation wants remotely. */
export const activeJourneyRouteWindowSchema = z
  .object({
    routeId: z.string().min(1).max(255),
    startsAt: z.iso.datetime({ offset: true }),
    endsAt: z.iso.datetime({ offset: true }),
  })
  .refine((value) => Date.parse(value.endsAt) > Date.parse(value.startsAt), {
    message: 'La fenêtre de ligne doit se terminer après son début.',
    path: ['endsAt'],
  });

export const activeJourneyRegistrationSchema = z
  .object({
    installationId: notificationInstallationIDSchema,
    journeyId: z.string().min(1).max(500),
    routeWindows: z.array(activeJourneyRouteWindowSchema).max(32).default([]),
    /** @deprecated Accepted during the route-window rolling migration. */
    routeIds: z.array(z.string().min(1).max(255)).max(64).default([]),
    startsAt: z.iso.datetime({ offset: true }),
    endsAt: z.iso.datetime({ offset: true }),
  })
  .refine((value) => Date.parse(value.endsAt) > Date.parse(value.startsAt), {
    message: 'La fenêtre du trajet doit se terminer après son début.',
    path: ['endsAt'],
  })
  .refine(
    (value) => value.routeWindows.length > 0 || value.routeIds.length > 0,
    {
      message: "Le trajet doit contenir au moins une ligne.",
      path: ["routeWindows"],
    },
  )
  .refine(
    (value) =>
      value.routeWindows.every(
        (window) =>
          Date.parse(window.startsAt) >= Date.parse(value.startsAt) &&
          Date.parse(window.endsAt) <= Date.parse(value.endsAt)
      ),
    {
      message: 'Chaque fenêtre de ligne doit rester dans la fenêtre du trajet.',
      path: ['routeWindows'],
    }
  );

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
