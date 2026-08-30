import {
  meetupPlanSchema,
  meetupResponseSchema,
  meetupStationSchema,
  type Meetup,
} from '@via/contract';
import type {
  MeetupInvitationRow,
  MeetupParticipantRow,
  MeetupRow,
} from '@via/db/schema';
import type { MeetupOriginCipher } from './origin-crypto';

export function projectMeetup({
  meetup,
  participants,
  invitations,
  currentParticipant,
  originCipher,
}: {
  meetup: MeetupRow;
  participants: MeetupParticipantRow[];
  invitations: MeetupInvitationRow[];
  currentParticipant: MeetupParticipantRow;
  originCipher: MeetupOriginCipher;
}): Meetup {
  const parsedPlan = meetup.plan === null ? undefined : meetupPlanSchema.parse(meetup.plan);
  const currentJourney = currentParticipant.journey === null
    ? undefined
    : originCipher.decryptJourney(currentParticipant.journey);
  const plan = parsedPlan === undefined
    ? undefined
    : {
        ...parsedPlan,
        participantJourneys: parsedPlan.participantJourneys.map((entry) => {
          const { journey: _persistedJourney, ...summary } = entry;
          return entry.participantId === currentParticipant.id && currentJourney !== undefined
            ? { ...summary, journey: currentJourney }
            : summary;
        }),
      };

  const projected = {
    id: meetup.id,
    destination: {
      id: meetup.destinationId,
      name: meetup.destinationName,
      coordinate: {
        latitude: meetup.destinationLatitude,
        longitude: meetup.destinationLongitude,
      },
    },
    targetArrivalAt: meetup.targetArrivalAt.toISOString(),
    phase: meetup.phase,
    revision: meetup.revision,
    keyRevision: meetup.keyRevision,
    currentParticipantId: currentParticipant.id,
    isOrganizer: currentParticipant.role === 'organizer',
    participants: participants
      .filter((participant) => participant.state !== 'removed' && participant.state !== 'left')
      .map((participant) => ({
        id: participant.id,
        displayName: participant.displayName,
        role: participant.role,
        state: participant.state,
        shareLevel: participant.shareLevel,
        zone: participant.zone,
        ...(participant.firstBoardingStation === null
          ? {}
          : { firstBoardingStation: meetupStationSchema.parse(participant.firstBoardingStation) }),
        ...(participant.departureAt === null
          ? {}
          : { departureAt: participant.departureAt.toISOString() }),
        ...(participant.arrivalAt === null
          ? {}
          : { arrivalAt: participant.arrivalAt.toISOString() }),
        createdAt: participant.createdAt.toISOString(),
        updatedAt: participant.updatedAt.toISOString(),
      })),
    ...(plan === undefined ? {} : { plan }),
    ...(currentParticipant.role !== 'organizer'
      ? {}
      : {
          invitations: invitations.map((invitation) => ({
            id: invitation.id,
            status: invitation.status,
            ...(invitation.invitedUserId === null
              ? {}
              : { invitedUserId: invitation.invitedUserId }),
            expiresAt: invitation.expiresAt.toISOString(),
            createdAt: invitation.createdAt.toISOString(),
          })),
        }),
    createdAt: meetup.createdAt.toISOString(),
    updatedAt: meetup.updatedAt.toISOString(),
  };

  return meetupResponseSchema.parse(projected);
}
