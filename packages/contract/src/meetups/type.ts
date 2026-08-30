import * as z from 'zod';

import {
  meetupCreateInputSchema,
  meetupCreateResponseSchema,
  meetupEncryptedPresenceSchema,
  meetupInvitationPreviewSchema,
  meetupJoinPointSchema,
  meetupLiveParticipantSchema,
  meetupPlanSchema,
  meetupProgressSchema,
  meetupResponseSchema,
  meetupShareLevelSchema,
  meetupStationSchema,
  meetupOriginSchema,
} from './schema';

export type Meetup = z.infer<typeof meetupResponseSchema>;
export type MeetupCreateInput = z.infer<typeof meetupCreateInputSchema>;
export type MeetupCreateResponse = z.infer<typeof meetupCreateResponseSchema>;
export type MeetupStation = z.infer<typeof meetupStationSchema>;
export type MeetupOrigin = z.infer<typeof meetupOriginSchema>;
export type MeetupPlan = z.infer<typeof meetupPlanSchema>;
export type MeetupJoinPoint = z.infer<typeof meetupJoinPointSchema>;
export type MeetupShareLevel = z.infer<typeof meetupShareLevelSchema>;
export type MeetupProgress = z.infer<typeof meetupProgressSchema>;
export type MeetupEncryptedPresence = z.infer<typeof meetupEncryptedPresenceSchema>;
export type MeetupLiveParticipant = z.infer<typeof meetupLiveParticipantSchema>;
export type MeetupInvitationPreview = z.infer<typeof meetupInvitationPreviewSchema>;
