import { oc } from '@orpc/contract';

import {
  meetupActivityTokenInputSchema,
  meetupActivityTokenRemoveInputSchema,
  meetupActivityTokenResponseSchema,
  meetupCancelInputSchema,
  meetupCreateInputSchema,
  meetupCreateResponseSchema,
  meetupGetInputSchema,
  meetupInvitationAcceptInputSchema,
  meetupInvitationAcceptResponseSchema,
  meetupInvitationCreateInputSchema,
  meetupInvitationCreateResponseSchema,
  meetupInvitationDeclineInputSchema,
  meetupInvitationPreviewInputSchema,
  meetupInvitationPreviewSchema,
  meetupInvitationRevokeInputSchema,
  meetupKeySyncInputSchema,
  meetupKeySyncResponseSchema,
  meetupLeaveInputSchema,
  meetupListInputSchema,
  meetupListResponseSchema,
  meetupLivePollInputSchema,
  meetupLivePollResponseSchema,
  meetupLivePublishInputSchema,
  meetupLivePublishResponseSchema,
  meetupMutationResponseSchema,
  meetupParticipantConfigureInputSchema,
  meetupRegisterDeviceKeyInputSchema,
  meetupRegisterDeviceKeyResponseSchema,
  meetupRemoveParticipantInputSchema,
  meetupResponseSchema,
  meetupUpdateInputSchema,
  meetupUploadKeyEnvelopesInputSchema,
  meetupUploadKeyEnvelopesResponseSchema,
} from './schema';

const post = (path: `/${string}`, summary: string, description: string) => ({
  method: 'POST' as const,
  path,
  summary,
  description,
  tags: ['meetups'],
});

export const meetupCreateRelation = oc
  .route(post('/meetups', 'Créer un rendez-vous', 'Crée un rendez-vous ponctuel et son Participant organisateur.'))
  .input(meetupCreateInputSchema)
  .output(meetupCreateResponseSchema);

export const meetupListRelation = oc
  .route({ method: 'GET', path: '/meetups', summary: 'Lister ses rendez-vous', tags: ['meetups'] })
  .input(meetupListInputSchema)
  .output(meetupListResponseSchema);

export const meetupGetRelation = oc
  .route({ method: 'GET', path: '/meetups/detail', summary: 'Lire un rendez-vous', tags: ['meetups'] })
  .input(meetupGetInputSchema)
  .output(meetupResponseSchema);

export const meetupUpdateRelation = oc
  .route(post('/meetups/update', 'Modifier un rendez-vous', 'Modifie la station C ou l\'heure puis recalcule le Plan de convergence.'))
  .input(meetupUpdateInputSchema)
  .output(meetupMutationResponseSchema);

export const meetupCancelRelation = oc
  .route(post('/meetups/cancel', 'Annuler un rendez-vous', 'Met fin au Rendez-vous et à tout Partage live.'))
  .input(meetupCancelInputSchema)
  .output(meetupMutationResponseSchema);

export const meetupInvitationCreateRelation = oc
  .route(post('/meetups/invitations', 'Inviter à un rendez-vous', 'Crée une Invitation par lien ou ciblée vers un Ami.'))
  .input(meetupInvitationCreateInputSchema)
  .output(meetupInvitationCreateResponseSchema);

export const meetupInvitationPreviewRelation = oc
  .route({ method: 'GET', path: '/meetups/invitations/preview', summary: 'Prévisualiser une invitation', tags: ['meetups'] })
  .input(meetupInvitationPreviewInputSchema)
  .output(meetupInvitationPreviewSchema);

export const meetupInvitationAcceptRelation = oc
  .route(post('/meetups/invitations/accept', 'Accepter une invitation', 'Crée un Participant et retourne sa capacité privée.'))
  .input(meetupInvitationAcceptInputSchema)
  .output(meetupInvitationAcceptResponseSchema);

export const meetupInvitationDeclineRelation = oc
  .route(post('/meetups/invitations/decline', 'Refuser une invitation', 'Refuse une Invitation sans créer de Participant.'))
  .input(meetupInvitationDeclineInputSchema)
  .output(meetupInvitationPreviewSchema);

export const meetupInvitationRevokeRelation = oc
  .route(post('/meetups/invitations/revoke', 'Révoquer une invitation', 'Empêche toute future acceptation de cette Invitation.'))
  .input(meetupInvitationRevokeInputSchema)
  .output(meetupMutationResponseSchema);

export const meetupParticipantConfigureRelation = oc
  .route(post('/meetups/participant', 'Configurer sa participation', 'Met à jour l\'origine privée, les préférences ou le Partage live.'))
  .input(meetupParticipantConfigureInputSchema)
  .output(meetupMutationResponseSchema);

export const meetupLeaveRelation = oc
  .route(post('/meetups/leave', 'Quitter un rendez-vous', 'Retire le Participant courant et invalide sa clé de groupe.'))
  .input(meetupLeaveInputSchema)
  .output(meetupMutationResponseSchema);

export const meetupRemoveParticipantRelation = oc
  .route(post('/meetups/remove', 'Retirer un participant', 'Retire un Participant en tant qu\'organisateur.'))
  .input(meetupRemoveParticipantInputSchema)
  .output(meetupMutationResponseSchema);

export const meetupLivePublishRelation = oc
  .route(post('/meetups/live', 'Publier sa progression', 'Publie la progression minimale et, avec consentement, une présence chiffrée.'))
  .input(meetupLivePublishInputSchema)
  .output(meetupLivePublishResponseSchema);

export const meetupLivePollRelation = oc
  .route({ method: 'GET', path: '/meetups/live', summary: 'Suivre un rendez-vous', tags: ['meetups'] })
  .input(meetupLivePollInputSchema)
  .output(meetupLivePollResponseSchema);

export const meetupRegisterDeviceKeyRelation = oc
  .route(post('/meetups/keys/device', 'Enregistrer une clé d\'installation', 'Associe une clé publique Curve25519 au Participant courant.'))
  .input(meetupRegisterDeviceKeyInputSchema)
  .output(meetupRegisterDeviceKeyResponseSchema);

export const meetupUploadKeyEnvelopesRelation = oc
  .route(post('/meetups/keys/envelopes', 'Distribuer la clé de groupe', 'Conserve les enveloppes chiffrées de la révision courante.'))
  .input(meetupUploadKeyEnvelopesInputSchema)
  .output(meetupUploadKeyEnvelopesResponseSchema);

export const meetupSyncKeysRelation = oc
  .route({ method: 'GET', path: '/meetups/keys', summary: 'Synchroniser les clés de groupe', tags: ['meetups'] })
  .input(meetupKeySyncInputSchema)
  .output(meetupKeySyncResponseSchema);

export const meetupRegisterActivityRelation = oc
  .route(post('/meetups/live-activity', 'Enregistrer une Live Activity de rendez-vous', 'Enregistre son jeton APNs sans donnée de position.'))
  .input(meetupActivityTokenInputSchema)
  .output(meetupActivityTokenResponseSchema);

export const meetupUnregisterActivityRelation = oc
  .route(post('/meetups/live-activity/unregister', 'Retirer une Live Activity de rendez-vous', 'Supprime le jeton ActivityKit associé.'))
  .input(meetupActivityTokenRemoveInputSchema)
  .output(meetupActivityTokenResponseSchema);
