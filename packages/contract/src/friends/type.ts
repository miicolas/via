import * as z from 'zod';

import {
  friendInvitationPreviewResponseSchema,
  friendInvitationSchema,
  friendshipSchema,
} from './schema';

export type Friendship = z.infer<typeof friendshipSchema>;
export type FriendInvitation = z.infer<typeof friendInvitationSchema>;
export type FriendInvitationPreview = z.infer<typeof friendInvitationPreviewResponseSchema>;
