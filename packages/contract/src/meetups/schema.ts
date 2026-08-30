import * as z from 'zod';

import {
  boardingPositionZoneSchema,
  journeyPlanningPolicySchema,
  journeySchema,
} from '../journeys/schema';
import { capabilityTokenSchema, coordinateSchema } from '../shared/schema';

export const MEETUP_PARTICIPANT_LIMIT = 4;
export const MEETUP_PLANNING_HORIZON_DAYS = 30;

/**
 * How long after the target arrival a Rendez-vous stays reachable: invitations
 * keep expiring at this offset, live publishing closes at it, and the runtime
 * expires the meetup past it. One window, named once, because the app enforces
 * the same deadline client-side before it publishes a position.
 */
export const MEETUP_GRACE_MS = 2 * 60 * 60 * 1_000;
export const MEETUP_PLANNING_HORIZON_MS = MEETUP_PLANNING_HORIZON_DAYS * 24 * 60 * 60 * 1_000;

export const meetupIdSchema = z.uuid();
export const meetupParticipantIdSchema = z.uuid();
export const meetupInvitationIdSchema = z.uuid();
export const meetupDeviceKeyIdSchema = z.uuid();

/** A URL-safe 256-bit capability. Only its SHA-256 digest is persisted. */
export const meetupTokenSchema = capabilityTokenSchema('meetup capability');

export const meetupStationSchema = z.object({
  id: z.string().min(1).max(500),
  name: z.string().trim().min(1).max(300),
  coordinate: coordinateSchema,
});

/** The complete place is private to its participant. */
export const meetupOriginSchema = z.object({
  kind: z.enum(['currentLocation', 'station', 'address', 'favorite']),
  id: z.string().min(1).max(500),
  name: z.string().trim().min(1).max(300),
  context: z.string().max(500).optional(),
  coordinate: coordinateSchema,
});

export const meetupPhaseSchema = z.enum([
  'draft',
  'planning',
  'ready',
  'live',
  'completed',
  'cancelled',
  'expired',
]);

export const meetupParticipantRoleSchema = z.enum(['organizer', 'member']);
export const meetupParticipantStateSchema = z.enum([
  'configuring',
  'ready',
  'underway',
  'joined',
  'arrived',
  'declined',
  'left',
  'removed',
]);
export const meetupShareLevelSchema = z.enum([
  'positionAndProgress',
  'progressOnly',
  'off',
]);

export const meetupProgressStatusSchema = z.enum([
  'planned',
  'waiting',
  'underway',
  'missed',
  'joined',
  'arrived',
  'stopped',
]);

/** Plaintext is deliberately limited to transit facts needed for replanning. */
export const meetupProgressSchema = z.object({
  status: meetupProgressStatusSchema,
  sectionId: z.string().min(1).max(500).optional(),
  serviceId: z.string().min(1).max(500).optional(),
  station: meetupStationSchema.optional(),
  expectedAt: z.iso.datetime({ offset: true }).optional(),
  updatedAt: z.iso.datetime({ offset: true }),
});

/** Accuracy and coordinates are inside `ciphertext`, never metadata. */
export const meetupEncryptedPresenceSchema = z.object({
  keyRevision: z.int().positive(),
  ciphertext: z.string().min(16).max(16_384),
  sentAt: z.iso.datetime({ offset: true }),
});

export const meetupPresenceFreshnessSchema = z.enum([
  'live',
  'delayed',
  'stale',
  'offline',
]);

export const meetupLiveParticipantSchema = z.object({
  participantId: meetupParticipantIdSchema,
  progress: meetupProgressSchema.optional(),
  presence: meetupEncryptedPresenceSchema.optional(),
  freshness: meetupPresenceFreshnessSchema,
});

export const meetupParticipantSchema = z.object({
  id: meetupParticipantIdSchema,
  displayName: z.string().trim().min(1).max(80),
  role: meetupParticipantRoleSchema,
  state: meetupParticipantStateSchema,
  shareLevel: meetupShareLevelSchema,
  zone: boardingPositionZoneSchema,
  firstBoardingStation: meetupStationSchema.optional(),
  departureAt: z.iso.datetime({ offset: true }).optional(),
  arrivalAt: z.iso.datetime({ offset: true }).optional(),
  createdAt: z.iso.datetime({ offset: true }),
  updatedAt: z.iso.datetime({ offset: true }),
});

export const meetupJoinPointSchema = z.object({
  id: z.string().min(1).max(500),
  station: meetupStationSchema,
  serviceId: z.string().min(1).max(500),
  meetAt: z.iso.datetime({ offset: true }),
  participantIds: z.array(meetupParticipantIdSchema).min(2).max(MEETUP_PARTICIPANT_LIMIT),
  zone: boardingPositionZoneSchema,
});

export const meetupParticipantJourneySchema = z.object({
  participantId: meetupParticipantIdSchema,
  departureAt: z.iso.datetime({ offset: true }),
  arrivalAt: z.iso.datetime({ offset: true }),
  firstBoardingStation: meetupStationSchema.optional(),
  /** Present only for the caller's own journey. */
  journey: journeySchema.optional(),
});

export const meetupPlanSchema = z.object({
  revision: z.int().nonnegative(),
  status: z.enum(['ready', 'fallbackAtDestination', 'unavailable']),
  generatedAt: z.iso.datetime({ offset: true }),
  isStale: z.boolean(),
  warning: z.string().max(500).optional(),
  participantJourneys: z
    .array(meetupParticipantJourneySchema)
    .max(MEETUP_PARTICIPANT_LIMIT),
  joinPoints: z.array(meetupJoinPointSchema).max(16),
});

export const meetupInvitationStatusSchema = z.enum([
  'pending',
  'accepted',
  'declined',
  'revoked',
  'expired',
]);

export const meetupInvitationSchema = z.object({
  id: meetupInvitationIdSchema,
  status: meetupInvitationStatusSchema,
  invitedUserId: z.string().min(1).max(500).optional(),
  expiresAt: z.iso.datetime({ offset: true }),
  createdAt: z.iso.datetime({ offset: true }),
});

export const meetupResponseSchema = z.object({
  id: meetupIdSchema,
  destination: meetupStationSchema,
  targetArrivalAt: z.iso.datetime({ offset: true }),
  phase: meetupPhaseSchema,
  revision: z.int().nonnegative(),
  keyRevision: z.int().positive(),
  currentParticipantId: meetupParticipantIdSchema,
  isOrganizer: z.boolean(),
  participants: z.array(meetupParticipantSchema).max(MEETUP_PARTICIPANT_LIMIT),
  plan: meetupPlanSchema.optional(),
  invitations: z.array(meetupInvitationSchema).max(MEETUP_PARTICIPANT_LIMIT).optional(),
  createdAt: z.iso.datetime({ offset: true }),
  updatedAt: z.iso.datetime({ offset: true }),
});

export const meetupCreateInputSchema = z.object({
  destination: meetupStationSchema,
  targetArrivalAt: z.iso.datetime({ offset: true }),
  organizerDisplayName: z.string().trim().min(1).max(80),
  origin: meetupOriginSchema,
  policy: journeyPlanningPolicySchema.optional(),
  shareLevel: meetupShareLevelSchema,
  publicKey: z.string().min(16).max(2_048),
  idempotencyKey: z.uuid(),
});

export const meetupCreateResponseSchema = z.object({
  meetup: meetupResponseSchema,
  participantToken: meetupTokenSchema,
});

export const meetupListInputSchema = z.object({});
export const meetupListResponseSchema = z.object({
  meetups: z.array(meetupResponseSchema).max(100),
  pendingInvitations: z.array(
    z.object({
      invitation: meetupInvitationSchema,
      /** Returned only to the authenticated direct recipient; never persisted raw. */
      token: meetupTokenSchema,
      meetupId: meetupIdSchema,
      organizerDisplayName: z.string().trim().min(1).max(80),
      destination: meetupStationSchema,
      targetArrivalAt: z.iso.datetime({ offset: true }),
    }),
  ).max(100),
});

export const meetupGetInputSchema = z.object({ meetupId: meetupIdSchema });

export const meetupUpdateInputSchema = z.object({
  meetupId: meetupIdSchema,
  destination: meetupStationSchema.optional(),
  targetArrivalAt: z.iso.datetime({ offset: true }).optional(),
}).refine((value) => value.destination !== undefined || value.targetArrivalAt !== undefined, {
  message: 'At least one meetup field must change',
});

export const meetupMutationResponseSchema = z.object({ meetup: meetupResponseSchema });
export const meetupCancelInputSchema = z.object({ meetupId: meetupIdSchema });

export const meetupKeyEnvelopeSchema = z.object({
  recipientKeyId: meetupDeviceKeyIdSchema,
  ciphertext: z.string().min(16).max(16_384),
});

export const meetupInvitationCreateInputSchema = z.object({
  meetupId: meetupIdSchema,
  invitedUserId: z.string().min(1).max(500).optional(),
  keyEnvelopes: z.array(meetupKeyEnvelopeSchema).max(16).default([]),
  idempotencyKey: z.uuid(),
});

export const meetupInvitationCreateResponseSchema = z.object({
  invitation: meetupInvitationSchema,
  token: meetupTokenSchema,
  url: z.url(),
});

export const meetupInvitationAcceptInputSchema = z.object({
  token: meetupTokenSchema,
  displayName: z.string().trim().min(1).max(80),
  origin: meetupOriginSchema,
  policy: journeyPlanningPolicySchema.optional(),
  shareLevel: meetupShareLevelSchema,
  publicKey: z.string().min(16).max(2_048),
  keyId: meetupDeviceKeyIdSchema,
  idempotencyKey: z.uuid(),
});

export const meetupInvitationAcceptResponseSchema = z.object({
  meetup: meetupResponseSchema,
  participantToken: meetupTokenSchema,
  keyEnvelopes: z.array(z.object({
    keyRevision: z.int().positive(),
    ciphertext: z.string().min(16).max(16_384),
  })).max(16),
});

export const meetupInvitationDeclineInputSchema = z.object({ token: meetupTokenSchema });
export const meetupInvitationRevokeInputSchema = z.object({
  meetupId: meetupIdSchema,
  invitationId: meetupInvitationIdSchema,
});

export const meetupParticipantConfigureInputSchema = z.object({
  meetupId: meetupIdSchema,
  origin: meetupOriginSchema.optional(),
  policy: journeyPlanningPolicySchema.optional(),
  shareLevel: meetupShareLevelSchema.optional(),
  zone: boardingPositionZoneSchema.optional(),
  publicKey: z.string().min(16).max(2_048).optional(),
}).refine(
  (value) =>
    value.origin !== undefined ||
    value.policy !== undefined ||
    value.shareLevel !== undefined ||
    value.zone !== undefined ||
    value.publicKey !== undefined,
  { message: 'At least one participant field must change' },
);

export const meetupLeaveInputSchema = z.object({ meetupId: meetupIdSchema });
export const meetupRemoveParticipantInputSchema = z.object({
  meetupId: meetupIdSchema,
  participantId: meetupParticipantIdSchema,
});

export const meetupLivePublishInputSchema = z.object({
  meetupId: meetupIdSchema,
  progress: meetupProgressSchema.optional(),
  presence: meetupEncryptedPresenceSchema.optional(),
}).refine((value) => value.progress !== undefined || value.presence !== undefined, {
  message: 'A progress or presence update is required',
});

export const meetupLivePublishResponseSchema = z.object({
  revision: z.int().nonnegative(),
  replanScheduled: z.boolean(),
});

export const meetupLivePollInputSchema = z.object({
  meetupId: meetupIdSchema,
  sinceRevision: z.coerce.number().int().nonnegative().default(0),
});

export const meetupLivePollResponseSchema = z.object({
  revision: z.int().nonnegative(),
  changed: z.boolean(),
  meetup: meetupResponseSchema.optional(),
  live: z.array(meetupLiveParticipantSchema).max(MEETUP_PARTICIPANT_LIMIT),
});

export const meetupRegisterDeviceKeyInputSchema = z.object({
  meetupId: meetupIdSchema,
  keyId: meetupDeviceKeyIdSchema,
  publicKey: z.string().min(16).max(2_048),
});
export const meetupRegisterDeviceKeyResponseSchema = z.object({ registered: z.literal(true) });

export const meetupUploadKeyEnvelopesInputSchema = z.object({
  meetupId: meetupIdSchema,
  keyRevision: z.int().positive(),
  envelopes: z.array(meetupKeyEnvelopeSchema).min(1).max(16),
});
export const meetupUploadKeyEnvelopesResponseSchema = z.object({ stored: z.int().nonnegative() });

export const meetupKeySyncInputSchema = z.object({ meetupId: meetupIdSchema });
export const meetupKeySyncResponseSchema = z.object({
  keyRevision: z.int().positive(),
  canRotate: z.boolean(),
  deviceKeys: z.array(z.object({
    keyId: meetupDeviceKeyIdSchema,
    participantId: meetupParticipantIdSchema,
    publicKey: z.string().min(16).max(2_048),
  })).max(16),
  envelopes: z.array(z.object({
    recipientKeyId: meetupDeviceKeyIdSchema,
    keyRevision: z.int().positive(),
    ciphertext: z.string().min(16).max(16_384),
  })).max(16),
});

export const meetupActivityTokenInputSchema = z.object({
  meetupId: meetupIdSchema,
  installationId: z.uuid(),
  activityId: z.string().min(1).max(500),
  token: z.string().min(1).max(4_096),
  environment: z.enum(['sandbox', 'production']),
});
export const meetupActivityTokenRemoveInputSchema = meetupActivityTokenInputSchema.pick({
  meetupId: true,
  installationId: true,
  activityId: true,
});
export const meetupActivityTokenResponseSchema = z.object({ registered: z.boolean() });

export const meetupInvitationPreviewSchema = z.object({
  organizerDisplayName: z.string().trim().min(1).max(80),
  destination: meetupStationSchema,
  targetArrivalAt: z.iso.datetime({ offset: true }),
  status: z.enum(['available', 'full', 'expired', 'revoked']),
  expiresAt: z.iso.datetime({ offset: true }),
});

export const meetupInvitationPreviewInputSchema = z.object({ token: meetupTokenSchema });
