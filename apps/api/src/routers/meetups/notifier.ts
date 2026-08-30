import { and, eq, inArray, isNotNull } from 'drizzle-orm';
import { MEETUP_GRACE_MS } from '@via/contract';
import { jobDb, meetupParticipants, meetups } from '@via/db';

import {
  fitDeviceNotification,
  stableIdentifierHash,
  type DeviceNotification,
  type NotificationDelivery,
} from '../../notifications';
import { ACTIVE_PARTICIPANT_STATES } from './aggregate';

type MeetupNotificationContext = {
  meetupId: string;
  destinationName: string;
  targetArrivalAt: Date;
  userIds: string[];
};

export type MeetupSemanticNotifier = {
  invitation(input: {
    userId: string;
    organizerDisplayName: string;
    destinationName: string;
    meetupId: string;
    invitationURL: string;
    expiresAt: Date;
  }): Promise<void>;
  planChanged(input: MeetupNotificationContext): Promise<void>;
  joinMissed(input: MeetupNotificationContext & { participantDisplayName: string }): Promise<void>;
  arrived(input: MeetupNotificationContext & { participantDisplayName: string }): Promise<void>;
  cancelled(input: MeetupNotificationContext): Promise<void>;
  departureSoon(meetupId: string): Promise<void>;
};

export function createMeetupSemanticNotifier(
  delivery: NotificationDelivery,
): MeetupSemanticNotifier {
  async function send(userIds: string[], notification: DeviceNotification) {
    if (!delivery.sendToUser) return;
    const payload = fitDeviceNotification(notification);
    await Promise.all([...new Set(userIds)].map((userId) =>
      delivery.sendToUser!(userId, payload)
    ));
  }

  const event = (
    input: MeetupNotificationContext,
    title: string,
    body: string,
    kind: string,
    interruptionLevel: DeviceNotification['interruptionLevel'] = 'active',
  ) => send(input.userIds, {
    title,
    body,
    threadId: `meetup-${stableIdentifierHash(input.meetupId)}`,
    collapseId: `meetup-${kind}-${stableIdentifierHash(input.meetupId)}`,
    expirationAt: new Date(input.targetArrivalAt.getTime() + MEETUP_GRACE_MS),
    interruptionLevel,
    data: { url: `via://meetup/${input.meetupId}`, meetupEvent: kind },
  });

  return {
    invitation(input) {
      return send([input.userId], {
        title: 'Invitation à un rendez-vous',
        body: `${input.organizerDisplayName} vous propose de vous retrouver à ${input.destinationName}.`,
        threadId: `meetup-${stableIdentifierHash(input.meetupId)}`,
        collapseId: `meetup-invitation-${stableIdentifierHash(input.meetupId)}`,
        expirationAt: input.expiresAt,
        interruptionLevel: 'active',
        data: { url: input.invitationURL, meetupEvent: 'invitation' },
      });
    },

    planChanged(input) {
      return event(
        input,
        'Nouveau plan de rendez-vous',
        `Le plan de convergence vers ${input.destinationName} a été recalculé.`,
        'plan',
      );
    },

    joinMissed(input) {
      return event(
        input,
        'Jonction à revoir',
        `${input.participantDisplayName} a raté son départ. Un nouveau point de jonction est prêt.`,
        'missed',
        'timeSensitive',
      );
    },

    arrived(input) {
      return event(
        input,
        'Arrivée au rendez-vous',
        `${input.participantDisplayName} est arrivé à ${input.destinationName}.`,
        'arrival',
      );
    },

    cancelled(input) {
      return event(
        input,
        'Rendez-vous annulé',
        `Le rendez-vous à ${input.destinationName} a été annulé.`,
        'cancelled',
        'timeSensitive',
      );
    },

    async departureSoon(meetupId) {
      const rows = await jobDb
        .select({
          userId: meetupParticipants.userId,
          destinationName: meetups.destinationName,
          targetArrivalAt: meetups.targetArrivalAt,
        })
        .from(meetupParticipants)
        .innerJoin(meetups, eq(meetupParticipants.meetupId, meetups.id))
        .where(and(
          eq(meetupParticipants.meetupId, meetupId),
          inArray(meetupParticipants.state, [...ACTIVE_PARTICIPANT_STATES]),
          isNotNull(meetupParticipants.userId),
        ));
      const first = rows[0];
      if (!first) return;
      await event({
        meetupId,
        destinationName: first.destinationName,
        targetArrivalAt: first.targetArrivalAt,
        userIds: rows.flatMap(({ userId }) => userId ? [userId] : []),
      }, 'Départ prochain', `Votre départ pour ${first.destinationName} approche.`, 'departure', 'timeSensitive');
    },
  };
}

export const noOpMeetupSemanticNotifier: MeetupSemanticNotifier = {
  async invitation() {},
  async planChanged() {},
  async joinMissed() {},
  async arrived() {},
  async cancelled() {},
  async departureSoon() {},
};
