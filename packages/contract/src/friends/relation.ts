import { oc } from '@orpc/contract';

import {
  friendInvitationAcceptInputSchema,
  friendInvitationAcceptResponseSchema,
  friendInvitationCreateInputSchema,
  friendInvitationCreateResponseSchema,
  friendInvitationPreviewInputSchema,
  friendInvitationPreviewResponseSchema,
  friendRemoveInputSchema,
  friendRemoveResponseSchema,
  friendsListInputSchema,
  friendsListResponseSchema,
} from './schema';

export const friendsListRelation = oc
  .route({ method: 'GET', path: '/friends', summary: 'Lister ses amis', tags: ['friends'] })
  .input(friendsListInputSchema)
  .output(friendsListResponseSchema);

export const friendInvitationCreateRelation = oc
  .route({ method: 'POST', path: '/friends/invitations', summary: 'Créer une invitation d\'ami', tags: ['friends'] })
  .input(friendInvitationCreateInputSchema)
  .output(friendInvitationCreateResponseSchema);

export const friendInvitationPreviewRelation = oc
  .route({ method: 'GET', path: '/friends/invitations/preview', summary: 'Prévisualiser une invitation d\'ami', tags: ['friends'] })
  .input(friendInvitationPreviewInputSchema)
  .output(friendInvitationPreviewResponseSchema);

export const friendInvitationAcceptRelation = oc
  .route({ method: 'POST', path: '/friends/invitations/accept', summary: 'Accepter une invitation d\'ami', tags: ['friends'] })
  .input(friendInvitationAcceptInputSchema)
  .output(friendInvitationAcceptResponseSchema);

export const friendRemoveRelation = oc
  .route({ method: 'POST', path: '/friends/remove', summary: 'Supprimer un ami', tags: ['friends'] })
  .input(friendRemoveInputSchema)
  .output(friendRemoveResponseSchema);
