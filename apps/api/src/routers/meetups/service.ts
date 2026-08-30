import { randomUUID } from 'node:crypto';

import {
  and,
  eq,
  gt,
  inArray,
  isNull,
  sql,
} from 'drizzle-orm';
import {
  MEETUP_GRACE_MS,
  MEETUP_PLANNING_HORIZON_MS,
  journeyPlanningPolicySchema,
  meetupInvitationPreviewSchema,
  meetupInvitationSchema,
  meetupKeyEnvelopeSchema,
  meetupOriginSchema,
  meetupProgressSchema,
  type Meetup,
  type MeetupInvitationPreview,
  type MeetupOrigin,
} from '@via/contract';
import {
  db,
  meetupActivityTokens,
  meetupDeviceKeys,
  meetupInvitations,
  meetupKeyEnvelopes,
  meetupParticipants,
  meetups,
  type MeetupInvitationRow,
  type MeetupParticipantRow,
} from '@via/db';

import type { ApiContext } from '../../orpc/implementer';
import { env } from '../../env';
import { areFriends } from '../friends/service';
import {
  ACTIVE_PARTICIPANT_STATES,
  ensureMutable,
  ensureOpen,
  meetupDestination,
  type RendezVous,
} from './aggregate';
import { capabilityToken, capabilityTokenHash } from './capability';
import { meetupConfigFromEnv, type MeetupServiceConfig } from './config';
import { MeetupServiceError } from './errors';
import type { MeetupLiveStore } from './live-store';
import {
  recordMeetupMetric,
  type MeetupMetric,
} from './metrics';
import type { MeetupSemanticNotifier } from './notifier';
import type { MeetupOriginCipher } from './origin-crypto';
import type { MeetupPlanningService } from './planning';
import { projectMeetup } from './projection';
import {
  authorizedParticipant,
  loadMeetupAggregate,
  loadMeetupAggregates,
  lockMeetup,
  lockRendezVous,
  meetupRevision,
  organizerDisplayNames,
  requireOrganizer,
} from './store';

const POST_EVENT_RETENTION_MS = 7 * 24 * 60 * 60 * 1_000;

type Dependencies = {
  planning: MeetupPlanningService;
  originCipher: MeetupOriginCipher;
  live: MeetupLiveStore;
  notifier: MeetupSemanticNotifier;
  clock: { now: () => Date };
  recordMetric?: (metric: MeetupMetric) => void;
  config?: MeetupServiceConfig;
};

export function createMeetupService(dependencies: Dependencies) {
  const { planning, originCipher, live, notifier, clock } = dependencies;
  const recordMetric = dependencies.recordMetric ?? recordMeetupMetric;
  const config = dependencies.config ?? meetupConfigFromEnv();

  async function read(meetupId: string, context: ApiContext): Promise<Meetup> {
    const currentParticipant = await authorizedParticipant(meetupId, context);
    const aggregate = await loadMeetupAggregate(meetupId);
    return projectMeetup({ ...aggregate, currentParticipant, originCipher });
  }

  /**
   * The tail every announcing mutation shares: one fresh aggregate feeds both
   * the notification audience and the response projection, instead of a load
   * per concern. The announcement is scheduled before the viewer check so a
   * Participant who just left still triggers the group's notification.
   */
  async function refreshAndAnnounce(
    meetupId: string,
    context: ApiContext,
    label: string,
    send: Parameters<typeof announce>[2],
  ): Promise<{ meetup: Meetup }> {
    const aggregate = await loadMeetupAggregate(meetupId);
    announce(label, aggregate, send);
    const currentParticipant = await authorizedParticipant(meetupId, context);
    return { meetup: projectMeetup({ ...aggregate, currentParticipant, originCipher }) };
  }

  async function create(input: {
    destination: { id: string; name: string; coordinate: { latitude: number; longitude: number } };
    targetArrivalAt: string;
    organizerDisplayName: string;
    origin: MeetupOrigin;
    policy?: unknown;
    shareLevel: 'positionAndProgress' | 'progressOnly' | 'off';
    publicKey: string;
    idempotencyKey: string;
  }, context: ApiContext) {
    const now = clock.now();
    const targetArrivalAt = validatedTarget(input.targetArrivalAt, now);
    const participantToken = capabilityToken(
      'meetup-participant',
      input.idempotencyKey,
      env.BETTER_AUTH_SECRET,
    );
    const existing = await participantByIdempotency(input.idempotencyKey);
    if (existing) {
      const aggregate = await loadMeetupAggregate(existing.meetupId);
      return {
        meetup: projectMeetup({ ...aggregate, currentParticipant: existing, originCipher }),
        participantToken,
      };
    }

    const meetupId = randomUUID();
    const participantId = randomUUID();
    const policy = journeyPlanningPolicySchema.parse(input.policy ?? {});
    await db.transaction(async (tx) => {
      await tx.insert(meetups).values({
        id: meetupId,
        organizerUserId: context.userId,
        destinationId: input.destination.id,
        destinationName: input.destination.name,
        destinationLatitude: input.destination.coordinate.latitude,
        destinationLongitude: input.destination.coordinate.longitude,
        targetArrivalAt,
        phase: 'planning',
        revision: 0,
        keyRevision: 1,
        createdAt: now,
        updatedAt: now,
        purgeAt: new Date(targetArrivalAt.getTime() + POST_EVENT_RETENTION_MS),
      });
      await tx.insert(meetupParticipants).values({
        id: participantId,
        meetupId,
        userId: context.userId,
        tokenHash: capabilityTokenHash(participantToken),
        idempotencyKey: input.idempotencyKey,
        displayName: input.organizerDisplayName,
        role: 'organizer',
        state: 'configuring',
        shareLevel: input.shareLevel,
        zone: 'middle',
        encryptedOrigin: originCipher.encrypt(input.origin),
        planningPolicy: policy,
        publicKey: input.publicKey,
        createdAt: now,
        updatedAt: now,
      });
    });

    await planning.recompute({
      meetupId,
      identity: requestIdentity(context, meetupId),
      reason: 'creation',
    });
    const aggregate = await loadMeetupAggregate(meetupId);
    const currentParticipant = aggregate.participants.find((item) => item.id === participantId);
    if (!currentParticipant) throw new MeetupServiceError('corrupt');
    const response = {
      meetup: projectMeetup({ ...aggregate, currentParticipant, originCipher }),
      participantToken,
    };
    recordMetric({ event: 'creation' });
    return response;
  }

  /**
   * Batched rather than one aggregate per meetup: this is the screen's first
   * paint, and a per-row `loadMeetupAggregate` turned an ordinary list into a
   * round trip per meetup plus one per pending invitation.
   */
  async function list(context: ApiContext) {
    if (!context.userId) return { meetups: [], pendingInvitations: [] };
    const ownedParticipants = await db
      .select()
      .from(meetupParticipants)
      .where(and(
        eq(meetupParticipants.userId, context.userId),
        inArray(meetupParticipants.state, [...ACTIVE_PARTICIPANT_STATES]),
      ));

    const [pendingRows, aggregates] = await Promise.all([
      db
        .select({ invitation: meetupInvitations, meetup: meetups })
        .from(meetupInvitations)
        .innerJoin(meetups, eq(meetupInvitations.meetupId, meetups.id))
        .where(and(
          eq(meetupInvitations.invitedUserId, context.userId),
          eq(meetupInvitations.status, 'pending'),
          gt(meetupInvitations.expiresAt, clock.now()),
        )),
      loadMeetupAggregates(ownedParticipants.map((row) => row.meetupId)),
    ]);

    const projectedMeetups = ownedParticipants.flatMap((currentParticipant) => {
      const aggregate = aggregates.get(currentParticipant.meetupId);
      if (!aggregate) return [];
      return [projectMeetup({ ...aggregate, currentParticipant, originCipher })];
    });

    // The organizer is already in the batch above whenever the invitee is a
    // participant; only an invitation to a meetup we are not in needs a read.
    const missingOrganizers = pendingRows
      .map(({ meetup }) => meetup.id)
      .filter((meetupId) => !aggregates.has(meetupId));
    const organizerNames = await organizerDisplayNames(missingOrganizers);
    for (const [meetupId, aggregate] of aggregates) {
      const organizer = aggregate.participants.find((row) => row.role === 'organizer');
      if (organizer) organizerNames.set(meetupId, organizer.displayName);
    }

    const pendingInvitations = pendingRows.map(({ invitation, meetup }) => ({
      invitation: invitationProjection(invitation),
      token: capabilityToken(
        'meetup-invitation',
        invitation.idempotencyKey,
        env.BETTER_AUTH_SECRET,
      ),
      meetupId: meetup.id,
      organizerDisplayName: organizerNames.get(meetup.id) ?? 'Un proche',
      destination: meetupDestination(meetup),
      targetArrivalAt: meetup.targetArrivalAt.toISOString(),
    }));

    return {
      meetups: projectedMeetups.sort(
        (left, right) => Date.parse(left.targetArrivalAt) - Date.parse(right.targetArrivalAt),
      ),
      pendingInvitations,
    };
  }

  async function update(input: {
    meetupId: string;
    destination?: { id: string; name: string; coordinate: { latitude: number; longitude: number } };
    targetArrivalAt?: string;
  }, context: ApiContext) {
    const current = await authorizedParticipant(input.meetupId, context);
    requireOrganizer(current);
    const aggregate = await loadMeetupAggregate(input.meetupId);
    ensureMutable(aggregate);
    const now = clock.now();
    const target = validatedTarget(
      input.targetArrivalAt ?? aggregate.meetup.targetArrivalAt.toISOString(),
      now,
    );
    await db.transaction(async (tx) => {
      await tx.update(meetups).set({
        ...(input.destination === undefined
          ? {}
          : {
              destinationId: input.destination.id,
              destinationName: input.destination.name,
              destinationLatitude: input.destination.coordinate.latitude,
              destinationLongitude: input.destination.coordinate.longitude,
            }),
        targetArrivalAt: target,
        phase: 'planning',
        revision: aggregate.meetup.revision + 1,
        updatedAt: now,
        purgeAt: new Date(target.getTime() + POST_EVENT_RETENTION_MS),
      }).where(eq(meetups.id, input.meetupId));
      await tx.update(meetupInvitations).set({
        expiresAt: new Date(target.getTime() + MEETUP_GRACE_MS),
      }).where(and(
        eq(meetupInvitations.meetupId, input.meetupId),
        eq(meetupInvitations.status, 'pending'),
      ));
    });
    await planning.recompute({
      meetupId: input.meetupId,
      identity: requestIdentity(context, input.meetupId),
      reason: 'organizer-update',
    });
    return refreshAndAnnounce(input.meetupId, context, 'plan', (notificationContext) =>
      notifier.planChanged(notificationContext)
    );
  }

  async function cancel(meetupId: string, context: ApiContext) {
    const current = await authorizedParticipant(meetupId, context);
    requireOrganizer(current);
    const aggregate = await loadMeetupAggregate(meetupId);
    ensureMutable(aggregate);
    const now = clock.now();
    await db.transaction(async (tx) => {
      await tx.update(meetups).set({
        phase: 'cancelled',
        revision: sql`${meetups.revision} + 1`,
        keyRevision: sql`${meetups.keyRevision} + 1`,
        updatedAt: now,
      }).where(eq(meetups.id, meetupId));
      await tx.update(meetupInvitations).set({
        status: 'revoked',
        revokedAt: now,
      }).where(and(
        eq(meetupInvitations.meetupId, meetupId),
        eq(meetupInvitations.status, 'pending'),
      ));
    });
    await Promise.all(aggregate.participants.map((participant) =>
      live.clearParticipant(meetupId, participant.id)
    ));
    return refreshAndAnnounce(meetupId, context, 'cancelled', (notificationContext) =>
      notifier.cancelled(notificationContext)
    );
  }

  async function createInvitation(input: {
    meetupId: string;
    invitedUserId?: string;
    keyEnvelopes: Array<{ recipientKeyId: string; ciphertext: string }>;
    idempotencyKey: string;
  }, context: ApiContext) {
    const current = await authorizedParticipant(input.meetupId, context);
    requireOrganizer(current);
    const aggregate = await loadMeetupAggregate(input.meetupId);
    ensureMutable(aggregate);
    if (input.invitedUserId) {
      if (!context.userId || !(await areFriends(context.userId, input.invitedUserId))) {
        throw new MeetupServiceError('forbidden');
      }
    }
    const token = capabilityToken(
      'meetup-invitation',
      input.idempotencyKey,
      env.BETTER_AUTH_SECRET,
    );
    const existing = aggregate.invitations.find(
      (invitation) => invitation.idempotencyKey === input.idempotencyKey,
    );
    if (existing) return invitationCreationResponse(existing, token, config.invitationURL(token));

    const now = clock.now();
    const invitation = await db.transaction(async (tx) => {
      const locked = await lockRendezVous(tx, input.meetupId);
      if (!locked) throw new MeetupServiceError('not_found');
      if (locked.seatsRemaining(now) <= 0) throw new MeetupServiceError('full');
      const rows = await tx.insert(meetupInvitations).values({
        id: randomUUID(),
        meetupId: input.meetupId,
        tokenHash: capabilityTokenHash(token),
        idempotencyKey: input.idempotencyKey,
        invitedUserId: input.invitedUserId,
        status: 'pending',
        createdAt: now,
        expiresAt: new Date(locked.meetup.targetArrivalAt.getTime() + MEETUP_GRACE_MS),
      }).returning();
      return rows[0];
    });
    if (!invitation) throw new MeetupServiceError('corrupt');
    if (input.keyEnvelopes.length > 0) {
      await storeEnvelopes(
        input.meetupId,
        aggregate.meetup.keyRevision,
        current,
        input.keyEnvelopes,
      );
    }
    const response = invitationCreationResponse(invitation, token, config.invitationURL(token));
    if (input.invitedUserId) {
      dispatch('invitation', notifier.invitation({
        userId: input.invitedUserId,
        organizerDisplayName: current.displayName,
        destinationName: aggregate.meetup.destinationName,
        meetupId: input.meetupId,
        invitationURL: response.url,
        expiresAt: invitation.expiresAt,
      }));
    }
    return response;
  }

  async function previewInvitation(token: string): Promise<MeetupInvitationPreview> {
    return getMeetupInvitationPreview(token, clock.now());
  }

  async function acceptInvitation(input: {
    token: string;
    displayName: string;
    origin: MeetupOrigin;
    policy?: unknown;
    shareLevel: 'positionAndProgress' | 'progressOnly' | 'off';
    publicKey: string;
    keyId: string;
    idempotencyKey: string;
  }, context: ApiContext) {
    const participantToken = capabilityToken(
      'meetup-participant',
      input.idempotencyKey,
      env.BETTER_AUTH_SECRET,
    );
    const idempotent = await participantByIdempotency(input.idempotencyKey);
    if (idempotent) {
      return (await acceptedResponse(idempotent, participantToken)).response;
    }
    const now = clock.now();
    const preview = await invitationPreviewRow(input.token);
    if (!preview) throw new MeetupServiceError('not_found');
    const meetupId = preview.aggregate.meetup.id;
    const participantId = randomUUID();
    const policy = journeyPlanningPolicySchema.parse(input.policy ?? {});

    await db.transaction(async (tx) => {
      const locked = await lockRendezVous(tx, meetupId);
      if (!locked) throw new MeetupServiceError('not_found');
      ensureOpen(locked, now);
      const invitation = locked.invitations.find((candidate) =>
        candidate.tokenHash === capabilityTokenHash(input.token)
          && candidate.status === 'pending'
      );
      if (!invitation) throw new MeetupServiceError('revoked');
      if (invitation.expiresAt <= now) throw new MeetupServiceError('expired');
      if (invitation.invitedUserId && invitation.invitedUserId !== context.userId) {
        throw new MeetupServiceError('forbidden');
      }
      if (!locked.invitationHasSeat(invitation.id, now)) {
        throw new MeetupServiceError('full');
      }
      await tx.insert(meetupParticipants).values({
        id: participantId,
        meetupId,
        userId: context.userId,
        tokenHash: capabilityTokenHash(participantToken),
        idempotencyKey: input.idempotencyKey,
        displayName: input.displayName,
        role: 'member',
        state: 'configuring',
        shareLevel: input.shareLevel,
        zone: 'middle',
        encryptedOrigin: originCipher.encrypt(input.origin),
        planningPolicy: policy,
        publicKey: input.publicKey,
        createdAt: now,
        updatedAt: now,
      });
      await tx.insert(meetupDeviceKeys).values({
        id: input.keyId,
        meetupId,
        participantId,
        userId: context.userId,
        publicKey: input.publicKey,
        createdAt: now,
      });
      await tx.update(meetupInvitations).set({
        status: 'accepted',
        claimedByParticipantId: participantId,
        respondedAt: now,
      }).where(eq(meetupInvitations.id, invitation.id));
      await tx.update(meetups).set({
        phase: 'planning',
        revision: locked.meetup.revision + 1,
        keyRevision: locked.meetup.keyRevision + 1,
        updatedAt: now,
      }).where(eq(meetups.id, meetupId));
    });

    await planning.recompute({
      meetupId,
      identity: requestIdentity(context, meetupId),
      reason: 'participant-accepted',
    });
    const participant = await participantById(participantId);
    if (!participant) throw new MeetupServiceError('corrupt');
    const { aggregate, response } = await acceptedResponse(participant, participantToken);
    announce('plan', aggregate, (notificationContext) =>
      notifier.planChanged(notificationContext)
    );
    recordMetric({ event: 'acceptance' });
    return response;
  }

  async function declineInvitation(token: string): Promise<MeetupInvitationPreview> {
    const row = await invitationPreviewRow(token);
    if (!row) throw new MeetupServiceError('not_found');
    const now = clock.now();
    await db.update(meetupInvitations).set({
      status: 'declined',
      respondedAt: now,
    }).where(and(
      eq(meetupInvitations.id, row.invitation.id),
      eq(meetupInvitations.status, 'pending'),
    ));
    return meetupInvitationPreviewSchema.parse({
      organizerDisplayName: row.organizerDisplayName,
      destination: meetupDestination(row.aggregate.meetup),
      targetArrivalAt: row.aggregate.meetup.targetArrivalAt.toISOString(),
      status: 'revoked',
      expiresAt: row.invitation.expiresAt.toISOString(),
    });
  }

  async function revokeInvitation(
    meetupId: string,
    invitationId: string,
    context: ApiContext,
  ) {
    const current = await authorizedParticipant(meetupId, context);
    requireOrganizer(current);
    const now = clock.now();
    await db.update(meetupInvitations).set({
      status: 'revoked',
      revokedAt: now,
    }).where(and(
      eq(meetupInvitations.id, invitationId),
      eq(meetupInvitations.meetupId, meetupId),
      eq(meetupInvitations.status, 'pending'),
    ));
    return { meetup: await read(meetupId, context) };
  }

  async function configureParticipant(input: {
    meetupId: string;
    origin?: MeetupOrigin;
    policy?: unknown;
    shareLevel?: 'positionAndProgress' | 'progressOnly' | 'off';
    zone?: 'front' | 'middle' | 'rear';
    publicKey?: string;
  }, context: ApiContext) {
    const participant = await authorizedParticipant(input.meetupId, context);
    const aggregate = await loadMeetupAggregate(input.meetupId);
    ensureOpen(aggregate, clock.now());
    const now = clock.now();
    await db.transaction(async (tx) => {
      await tx.update(meetupParticipants).set({
        ...(input.origin === undefined
          ? {}
          : { encryptedOrigin: originCipher.encrypt(meetupOriginSchema.parse(input.origin)) }),
        ...(input.policy === undefined
          ? {}
          : { planningPolicy: journeyPlanningPolicySchema.parse(input.policy) }),
        ...(input.shareLevel === undefined ? {} : { shareLevel: input.shareLevel }),
        ...(input.zone === undefined ? {} : { zone: input.zone }),
        ...(input.publicKey === undefined ? {} : { publicKey: input.publicKey }),
        updatedAt: now,
      }).where(eq(meetupParticipants.id, participant.id));
      await tx.update(meetups).set({
        phase: input.origin !== undefined || input.policy !== undefined ? 'planning' : aggregate.meetup.phase,
        revision: aggregate.meetup.revision + 1,
        updatedAt: now,
      }).where(eq(meetups.id, input.meetupId));
    });
    if (input.shareLevel !== undefined && input.shareLevel !== 'positionAndProgress') {
      await live.clearParticipant(input.meetupId, participant.id);
    }
    if (input.origin !== undefined || input.policy !== undefined) {
      await planning.recompute({
        meetupId: input.meetupId,
        identity: requestIdentity(context, input.meetupId),
        reason: 'origin-change',
      });
      return refreshAndAnnounce(input.meetupId, context, 'plan', (notificationContext) =>
        notifier.planChanged(notificationContext)
      );
    }
    await live.bump(input.meetupId, aggregate.meetup.revision + 1);
    return { meetup: await read(input.meetupId, context) };
  }

  async function leave(meetupId: string, context: ApiContext) {
    const participant = await authorizedParticipant(meetupId, context);
    if (participant.role === 'organizer') throw new MeetupServiceError('conflict');
    return removeParticipantRecord(meetupId, participant, 'left', context);
  }

  async function removeParticipant(
    meetupId: string,
    participantId: string,
    context: ApiContext,
  ) {
    const organizer = await authorizedParticipant(meetupId, context);
    requireOrganizer(organizer);
    const participant = await participantById(participantId);
    if (!participant || participant.meetupId !== meetupId) throw new MeetupServiceError('not_found');
    if (participant.role === 'organizer') throw new MeetupServiceError('conflict');
    return removeParticipantRecord(meetupId, participant, 'removed', context);
  }

  async function removeParticipantRecord(
    meetupId: string,
    participant: MeetupParticipantRow,
    state: 'left' | 'removed',
    context: ApiContext,
  ) {
    const aggregate = await loadMeetupAggregate(meetupId);
    ensureMutable(aggregate);
    const now = clock.now();
    await db.transaction(async (tx) => {
      await lockMeetup(tx, meetupId);
      await tx.update(meetupParticipants).set({ state, updatedAt: now })
        .where(eq(meetupParticipants.id, participant.id));
      await tx.update(meetups).set({
        phase: 'planning',
        revision: sql`${meetups.revision} + 1`,
        keyRevision: sql`${meetups.keyRevision} + 1`,
        updatedAt: now,
      }).where(eq(meetups.id, meetupId));
      await tx.update(meetupDeviceKeys).set({ revokedAt: now })
        .where(eq(meetupDeviceKeys.participantId, participant.id));
    });
    await live.clearParticipant(meetupId, participant.id);
    await planning.recompute({
      meetupId,
      identity: requestIdentity(context, meetupId),
      reason: 'member-change',
    });
    return refreshAndAnnounce(meetupId, context, 'plan', (notificationContext) =>
      notifier.planChanged(notificationContext)
    );
  }

  async function publishLive(input: {
    meetupId: string;
    progress?: unknown;
    presence?: { keyRevision: number; ciphertext: string; sentAt: string };
  }, context: ApiContext) {
    const participant = await authorizedParticipant(input.meetupId, context);
    const aggregate = await loadMeetupAggregate(input.meetupId);
    ensureOpen(aggregate, clock.now());
    const progress = input.progress === undefined ? undefined : meetupProgressSchema.parse(input.progress);
    if (input.presence && participant.shareLevel !== 'positionAndProgress') {
      throw new MeetupServiceError('privacy');
    }
    if (input.presence && !config.precisePresenceEnabled) {
      throw new MeetupServiceError('privacy');
    }
    if (input.presence && input.presence.keyRevision !== aggregate.meetup.keyRevision) {
      throw new MeetupServiceError('conflict');
    }

    const isPrivateSignalOnly = participant.shareLevel === 'off';
    if (isPrivateSignalOnly && progress?.status !== 'missed' && progress?.status !== 'arrived') {
      throw new MeetupServiceError('privacy');
    }
    const previousProgress = progress?.status === 'missed' && !isPrivateSignalOnly
      ? (await live.read(input.meetupId, [participant.id]))[0]?.progress
      : undefined;
    const now = clock.now();
    const state = progressState(progress?.status, participant.state);
    await db.transaction(async (tx) => {
      if (state !== participant.state) {
        await tx.update(meetupParticipants).set({ state, updatedAt: now })
          .where(eq(meetupParticipants.id, participant.id));
      }
      if (progress?.status === 'underway' && aggregate.meetup.phase !== 'live') {
        await tx.update(meetups).set({ phase: 'live', updatedAt: now })
          .where(eq(meetups.id, input.meetupId));
      }
    });

    let revision = aggregate.meetup.revision;
    if (!isPrivateSignalOnly) {
      revision = await live.publish({
        meetupId: input.meetupId,
        participantId: participant.id,
        baseRevision: aggregate.meetup.revision,
        clearPresence: progress?.status === 'stopped' || progress?.status === 'arrived',
        ...(progress === undefined ? {} : { progress }),
        ...(input.presence === undefined ? {} : { presence: input.presence }),
      });
    } else {
      await live.clearParticipant(input.meetupId, participant.id);
      revision = await live.bump(input.meetupId, aggregate.meetup.revision);
    }

    const shouldReplan = progress?.status === 'missed'
      && progress.station !== undefined
      && (previousProgress?.status !== 'missed'
        || previousProgress.station?.id !== progress.station.id);
    if (shouldReplan) {
      const override = new Map<string, MeetupOrigin>([[participant.id, {
        kind: 'station',
        id: progress.station!.id,
        name: progress.station!.name,
        coordinate: progress.station!.coordinate,
      }]]);
      await planning.recompute({
        meetupId: input.meetupId,
        identity: requestIdentity(context, input.meetupId),
        reason: 'missed-connection',
        overrideOrigins: override,
      });
      revision = await live.bump(input.meetupId, revision);
      announce('missed', aggregate, (notificationContext) =>
        notifier.joinMissed({
          ...notificationContext,
          participantDisplayName: participant.displayName,
        })
      );
    }
    if (progress?.status === 'arrived') {
      announce('arrival', aggregate, (notificationContext) =>
        notifier.arrived({
          ...notificationContext,
          userIds: notificationContext.userIds.filter((userId) => userId !== participant.userId),
          participantDisplayName: participant.displayName,
        })
      );
      await completeWhenEveryoneArrived(input.meetupId);
    }
    if (progress?.status === 'joined' && participant.state !== 'joined') {
      recordMetric({ event: 'join-succeeded' });
    }
    return { revision, replanScheduled: shouldReplan };
  }

  async function pollLive(
    meetupId: string,
    sinceRevision: number,
    context: ApiContext,
  ) {
    const currentParticipant = await authorizedParticipant(meetupId, context);
    // The unchanged answer is the common one, so it costs a single narrow
    // read rather than the full aggregate.
    const revision = await live.revision(meetupId, await meetupRevision(meetupId));
    if (revision <= sinceRevision) return { revision, changed: false, live: [] };

    const aggregate = await loadMeetupAggregate(meetupId);
    const visibleParticipants = aggregate.isOpen(clock.now()) ? aggregate.participants.filter(
      (participant) =>
        participant.shareLevel !== 'off' &&
        participant.state !== 'left' &&
        participant.state !== 'removed',
    ) : [];
    const storedLiveParticipants = await live.read(
      meetupId,
      visibleParticipants.map((participant) => participant.id),
    );
    const liveParticipants = storedLiveParticipants.map((participant) => {
      const canExposePresence = config.precisePresenceEnabled
        && participant.presence?.keyRevision === aggregate.meetup.keyRevision;
      if (participant.presence === undefined || canExposePresence) return participant;
      const { presence: _presence, ...withoutPresence } = participant;
      return withoutPresence;
    });
    for (const participant of liveParticipants) {
      recordMetric({ event: 'freshness', category: participant.freshness });
    }
    return {
      revision,
      changed: true,
      meetup: projectMeetup({ ...aggregate, currentParticipant, originCipher }),
      live: liveParticipants,
    };
  }

  async function registerDeviceKey(
    meetupId: string,
    keyId: string,
    publicKey: string,
    context: ApiContext,
  ) {
    const participant = await authorizedParticipant(meetupId, context);
    let revision: number | undefined;
    await db.transaction(async (tx) => {
      await lockMeetup(tx, meetupId);
      const existing = await tx.select().from(meetupDeviceKeys)
        .where(eq(meetupDeviceKeys.id, keyId)).limit(1);
      const current = existing[0];
      if (current && (
        current.meetupId !== meetupId || current.participantId !== participant.id
      )) throw new MeetupServiceError('conflict');
      if (current?.publicKey === publicKey && current.revokedAt === null) return;

      if (current) {
        await tx.update(meetupDeviceKeys).set({ publicKey, revokedAt: null })
          .where(eq(meetupDeviceKeys.id, keyId));
        // An envelope is bound to the previous private key and must never be
        // considered coverage for the replacement public key.
        await tx.delete(meetupKeyEnvelopes)
          .where(eq(meetupKeyEnvelopes.recipientKeyId, keyId));
      } else {
        await tx.insert(meetupDeviceKeys).values({
          id: keyId,
          meetupId,
          participantId: participant.id,
          userId: participant.userId,
          publicKey,
          createdAt: clock.now(),
        });
      }
      await tx.update(meetupParticipants).set({ publicKey, updatedAt: clock.now() })
        .where(eq(meetupParticipants.id, participant.id));
      const rows = await tx.update(meetups).set({
        revision: sql`${meetups.revision} + 1`,
        updatedAt: clock.now(),
      }).where(eq(meetups.id, meetupId)).returning({ revision: meetups.revision });
      revision = rows[0]?.revision;
    });
    if (revision !== undefined) await live.bump(meetupId, revision);
    return { registered: true as const };
  }

  async function uploadKeyEnvelopes(
    meetupId: string,
    keyRevision: number,
    envelopes: Array<{ recipientKeyId: string; ciphertext: string }>,
    context: ApiContext,
  ) {
    const participant = await authorizedParticipant(meetupId, context);
    requireOrganizer(participant);
    const aggregate = await loadMeetupAggregate(meetupId);
    ensureMutable(aggregate);
    if (keyRevision !== aggregate.meetup.keyRevision) throw new MeetupServiceError('conflict');
    const stored = await storeEnvelopes(meetupId, keyRevision, participant, envelopes);
    return { stored };
  }

  async function syncKeys(meetupId: string, context: ApiContext) {
    const participant = await authorizedParticipant(meetupId, context);
    const aggregate = await loadMeetupAggregate(meetupId);
    const activeParticipantIds = aggregate.activeParticipants()
      .map((candidate) => candidate.id);
    const keys = activeParticipantIds.length === 0
      ? []
      : await db.select({
          keyId: meetupDeviceKeys.id,
          participantId: meetupDeviceKeys.participantId,
          publicKey: meetupDeviceKeys.publicKey,
        }).from(meetupDeviceKeys).where(and(
          eq(meetupDeviceKeys.meetupId, meetupId),
          inArray(meetupDeviceKeys.participantId, activeParticipantIds),
          isNull(meetupDeviceKeys.revokedAt),
        ));
    const ownKeyIds = keys
      .filter((key) => key.participantId === participant.id)
      .map((key) => key.keyId);
    const visibleEnvelopeKeyIds = participant.role === 'organizer'
      ? keys.map((key) => key.keyId)
      : ownKeyIds;
    const envelopes = visibleEnvelopeKeyIds.length === 0
      ? []
      : await db.select({
          recipientKeyId: meetupKeyEnvelopes.recipientKeyId,
          keyRevision: meetupKeyEnvelopes.keyRevision,
          ciphertext: meetupKeyEnvelopes.ciphertext,
        }).from(meetupKeyEnvelopes).where(and(
          eq(meetupKeyEnvelopes.meetupId, meetupId),
          eq(meetupKeyEnvelopes.keyRevision, aggregate.meetup.keyRevision),
          inArray(meetupKeyEnvelopes.recipientKeyId, visibleEnvelopeKeyIds),
        ));
    return {
      keyRevision: aggregate.meetup.keyRevision,
      canRotate: participant.role === 'organizer',
      deviceKeys: participant.role === 'organizer'
        ? keys
        : keys.filter((key) => key.participantId === participant.id),
      envelopes,
    };
  }

  async function registerActivity(input: {
    meetupId: string;
    installationId: string;
    activityId: string;
    token: string;
    environment: 'sandbox' | 'production';
  }, context: ApiContext) {
    const participant = await authorizedParticipant(input.meetupId, context);
    const now = clock.now();
    const existing = await db.select({ participantId: meetupActivityTokens.participantId })
      .from(meetupActivityTokens)
      .where(and(
        eq(meetupActivityTokens.meetupId, input.meetupId),
        eq(meetupActivityTokens.installationId, input.installationId),
        eq(meetupActivityTokens.activityId, input.activityId),
      )).limit(1);
    if (existing[0] && existing[0].participantId !== participant.id) {
      throw new MeetupServiceError('forbidden');
    }
    await db.insert(meetupActivityTokens).values({
      ...input,
      participantId: participant.id,
      createdAt: now,
      updatedAt: now,
    }).onConflictDoUpdate({
      target: [
        meetupActivityTokens.meetupId,
        meetupActivityTokens.installationId,
        meetupActivityTokens.activityId,
      ],
      set: { token: input.token, environment: input.environment, updatedAt: now },
    });
    return { registered: true };
  }

  async function unregisterActivity(input: {
    meetupId: string;
    installationId: string;
    activityId: string;
  }, context: ApiContext) {
    const participant = await authorizedParticipant(input.meetupId, context);
    await db.delete(meetupActivityTokens).where(and(
      eq(meetupActivityTokens.meetupId, input.meetupId),
      eq(meetupActivityTokens.participantId, participant.id),
      eq(meetupActivityTokens.installationId, input.installationId),
      eq(meetupActivityTokens.activityId, input.activityId),
    ));
    return { registered: false };
  }

  async function acceptedResponse(participant: MeetupParticipantRow, participantToken: string) {
    const aggregate = await loadMeetupAggregate(participant.meetupId);
    const envelopes = await db
      .select({
        keyRevision: meetupKeyEnvelopes.keyRevision,
        ciphertext: meetupKeyEnvelopes.ciphertext,
      })
      .from(meetupKeyEnvelopes)
      .innerJoin(meetupDeviceKeys, eq(meetupKeyEnvelopes.recipientKeyId, meetupDeviceKeys.id))
      .where(and(
        eq(meetupDeviceKeys.participantId, participant.id),
        eq(meetupKeyEnvelopes.keyRevision, aggregate.meetup.keyRevision),
      ));
    return {
      aggregate,
      response: {
        meetup: projectMeetup({ ...aggregate, currentParticipant: participant, originCipher }),
        participantToken,
        keyEnvelopes: envelopes,
      },
    };
  }

  async function storeEnvelopes(
    meetupId: string,
    keyRevision: number,
    sender: MeetupParticipantRow,
    envelopes: Array<{ recipientKeyId: string; ciphertext: string }>,
  ): Promise<number> {
    const parsed = envelopes.map((envelope) => meetupKeyEnvelopeSchema.parse(envelope));
    const keyIds = parsed.map((envelope) => envelope.recipientKeyId);
    return db.transaction(async (tx) => {
      const locked = await lockMeetup(tx, meetupId);
      if (!locked) throw new MeetupServiceError('not_found');
      if (locked.keyRevision !== keyRevision) {
        throw new MeetupServiceError('conflict');
      }
      const keys = await tx.select({ id: meetupDeviceKeys.id }).from(meetupDeviceKeys).where(and(
        eq(meetupDeviceKeys.meetupId, meetupId),
        inArray(meetupDeviceKeys.id, keyIds),
        sql`${meetupDeviceKeys.revokedAt} IS NULL`,
      ));
      if (keys.length !== new Set(keyIds).size) throw new MeetupServiceError('forbidden');
      const existing = await tx.select({
        recipientKeyId: meetupKeyEnvelopes.recipientKeyId,
      }).from(meetupKeyEnvelopes).where(and(
        eq(meetupKeyEnvelopes.meetupId, meetupId),
        eq(meetupKeyEnvelopes.keyRevision, keyRevision),
        inArray(meetupKeyEnvelopes.recipientKeyId, keyIds),
      ));
      const alreadyStored = new Set(existing.map((row) => row.recipientKeyId));
      const pending = parsed.filter((envelope) => !alreadyStored.has(envelope.recipientKeyId));
      if (pending.length === 0) return 0;
      // One statement: the loop held the meetup row lock for a round trip per
      // envelope, and there is one envelope per recipient device.
      const inserted = await tx.insert(meetupKeyEnvelopes).values(
        pending.map((envelope) => ({
          meetupId,
          keyRevision,
          recipientKeyId: envelope.recipientKeyId,
          senderParticipantId: sender.id,
          ciphertext: envelope.ciphertext,
          createdAt: clock.now(),
        })),
      ).onConflictDoNothing().returning({
        recipientKeyId: meetupKeyEnvelopes.recipientKeyId,
      });
      return inserted.length;
    });
  }

  async function completeWhenEveryoneArrived(meetupId: string) {
    const now = clock.now();
    const completedParticipantIds = await db.transaction(async (tx) => {
      const locked = await lockRendezVous(tx, meetupId);
      if (!locked || !locked.isMutable()) return [];
      const active = locked.activeParticipants();
      if (active.length === 0 || active.some((participant) => participant.state !== 'arrived')) {
        return [];
      }
      await tx.update(meetups).set({
        phase: 'completed',
        revision: sql`${meetups.revision} + 1`,
        keyRevision: sql`${meetups.keyRevision} + 1`,
        updatedAt: now,
      }).where(eq(meetups.id, meetupId));
      await tx.update(meetupInvitations).set({
        status: 'revoked',
        revokedAt: now,
      }).where(and(
        eq(meetupInvitations.meetupId, meetupId),
        eq(meetupInvitations.status, 'pending'),
      ));
      return active.map(({ id }) => id);
    });
    await Promise.all(completedParticipantIds.map((participantId) =>
      live.clearParticipant(meetupId, participantId)
    ));
  }

  function announce(
    label: string,
    aggregate: RendezVous,
    send: (context: {
      meetupId: string;
      destinationName: string;
      targetArrivalAt: Date;
      userIds: string[];
    }) => Promise<void>,
  ) {
    dispatch(label, send({
      meetupId: aggregate.meetup.id,
      destinationName: aggregate.meetup.destinationName,
      targetArrivalAt: aggregate.meetup.targetArrivalAt,
      userIds: aggregate.activeParticipants().flatMap((candidate) =>
        candidate.userId ? [candidate.userId] : []
      ),
    }));
  }

  function dispatch(label: string, work: Promise<void>) {
    void work.catch(() => {
      console.error('[meetups] semantic notification failed', { event: label });
    });
  }

  return {
    create,
    list,
    read,
    update,
    cancel,
    createInvitation,
    previewInvitation,
    acceptInvitation,
    declineInvitation,
    revokeInvitation,
    configureParticipant,
    leave,
    removeParticipant,
    publishLive,
    pollLive,
    registerDeviceKey,
    uploadKeyEnvelopes,
    syncKeys,
    registerActivity,
    unregisterActivity,
  };
}

export async function getMeetupInvitationPreview(
  token: string,
  now = new Date(),
): Promise<MeetupInvitationPreview> {
  const row = await invitationPreviewRow(token);
  if (!row) throw new MeetupServiceError('not_found');
  const { invitation, aggregate } = row;
  const terminalPhase = ['cancelled', 'completed'].includes(aggregate.meetup.phase);
  const eventExpired = aggregate.meetup.phase === 'expired'
    || !aggregate.withinGraceWindow(now);
  const status = invitation.revokedAt || invitation.status === 'revoked' || terminalPhase
    ? 'revoked'
    : invitation.expiresAt <= now || invitation.status === 'expired' || eventExpired
      ? 'expired'
      : invitation.status !== 'pending'
        ? 'revoked'
        : aggregate.invitationHasSeat(invitation.id, now)
          ? 'available'
          : 'full';
  return meetupInvitationPreviewSchema.parse({
    organizerDisplayName: row.organizerDisplayName,
    destination: meetupDestination(aggregate.meetup),
    targetArrivalAt: aggregate.meetup.targetArrivalAt.toISOString(),
    status,
    expiresAt: invitation.expiresAt.toISOString(),
  });
}

async function participantByIdempotency(idempotencyKey: string) {
  const rows = await db.select().from(meetupParticipants)
    .where(eq(meetupParticipants.idempotencyKey, idempotencyKey)).limit(1);
  return rows[0];
}

async function participantById(id: string) {
  const rows = await db.select().from(meetupParticipants)
    .where(eq(meetupParticipants.id, id)).limit(1);
  return rows[0];
}

async function invitationPreviewRow(token: string) {
  const invitationRows = await db.select().from(meetupInvitations)
    .where(eq(meetupInvitations.tokenHash, capabilityTokenHash(token))).limit(1);
  const invitation = invitationRows[0];
  if (!invitation) return undefined;
  const aggregate = await loadMeetupAggregate(invitation.meetupId);
  const organizer = aggregate.participants.find((participant) => participant.role === 'organizer');
  if (!organizer) throw new MeetupServiceError('corrupt');
  return {
    invitation,
    aggregate,
    organizerDisplayName: organizer.displayName,
  };
}

function invitationCreationResponse(
  invitation: MeetupInvitationRow,
  token: string,
  url: string,
) {
  return {
    invitation: invitationProjection(invitation),
    token,
    url,
  };
}

function invitationProjection(invitation: MeetupInvitationRow) {
  return meetupInvitationSchema.parse({
    id: invitation.id,
    status: invitation.status,
    ...(invitation.invitedUserId === null ? {} : { invitedUserId: invitation.invitedUserId }),
    expiresAt: invitation.expiresAt.toISOString(),
    createdAt: invitation.createdAt.toISOString(),
  });
}

function validatedTarget(raw: string, now: Date): Date {
  const target = new Date(raw);
  if (!Number.isFinite(target.getTime())) throw new MeetupServiceError('invalid_time');
  if (target.getTime() < now.getTime() - 60_000) throw new MeetupServiceError('invalid_time');
  if (target.getTime() > now.getTime() + MEETUP_PLANNING_HORIZON_MS) {
    throw new MeetupServiceError('invalid_time');
  }
  return target;
}

function requestIdentity(context: ApiContext, meetupId: string) {
  return context.userId ?? context.requestIPHash?.() ?? `meetup:${meetupId}`;
}

function progressState(
  status: string | undefined,
  current: MeetupParticipantRow['state'],
): MeetupParticipantRow['state'] {
  switch (status) {
  case 'underway': return 'underway';
  case 'joined': return 'joined';
  case 'arrived': return 'arrived';
  case 'stopped': return 'ready';
  default: return current;
  }
}
