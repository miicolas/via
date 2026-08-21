import { oc } from '@orpc/contract';

import {
  activeJourneyRegistrationSchema,
  activeJourneyUnregistrationSchema,
  notificationDeviceRegistrationSchema,
  notificationDeviceUnregistrationSchema,
  notificationRegistrationResponseSchema,
  notificationRemovalResponseSchema,
  liveActivityPushToStartRegistrationSchema,
  liveActivityRegistrationSchema,
  liveActivityUnregistrationSchema,
} from './schema';

export const notificationsRegisterActiveJourneyRelation = oc
  .route({
    method: 'POST',
    path: '/notifications/active-journey',
    summary: 'Enregistrer un trajet actif pour les perturbations',
    description: 'Associe une installation authentifiée à la fenêtre et aux lignes d’un trajet suivi.',
    tags: ['notifications'],
  })
  .input(activeJourneyRegistrationSchema)
  .output(notificationRegistrationResponseSchema);

export const notificationsUnregisterActiveJourneyRelation = oc
  .route({
    method: 'POST',
    path: '/notifications/active-journey/unregister',
    summary: 'Désinscrire un trajet actif',
    description: 'Supprime l’abonnement de perturbations d’un trajet terminé.',
    tags: ['notifications'],
  })
  .input(activeJourneyUnregistrationSchema)
  .output(notificationRemovalResponseSchema);

export const notificationsRegisterDeviceRelation = oc
  .route({
    method: 'POST',
    path: '/notifications/device',
    summary: 'Enregistrer un appareil pour les notifications',
    description: 'Associe le token APNs de l’installation au compte courant.',
    tags: ['notifications'],
  })
  .input(notificationDeviceRegistrationSchema)
  .output(notificationRegistrationResponseSchema);

export const notificationsUnregisterDeviceRelation = oc
  .route({
    method: 'POST',
    path: '/notifications/device/unregister',
    summary: 'Désinscrire un appareil des notifications',
    description: 'Supprime les tokens de l’installation pour le compte courant.',
    tags: ['notifications'],
  })
  .input(notificationDeviceUnregistrationSchema)
  .output(notificationRemovalResponseSchema);

export const notificationsRegisterActivityRelation = oc
  .route({
    method: 'POST',
    path: '/notifications/live-activity',
    summary: 'Compatibilité Live Activity locale',
    description: 'Accepte sans persister les tokens envoyés par les anciennes versions iOS.',
    tags: ['notifications'],
  })
  .input(liveActivityRegistrationSchema)
  .output(notificationRegistrationResponseSchema);

export const notificationsUnregisterActivityRelation = oc
  .route({
    method: 'POST',
    path: '/notifications/live-activity/unregister',
    summary: 'Compatibilité Live Activity locale',
    description: 'Accepte la désinscription des anciennes versions iOS.',
    tags: ['notifications'],
  })
  .input(liveActivityUnregistrationSchema)
  .output(notificationRemovalResponseSchema);

export const notificationsRegisterPushToStartRelation = oc
  .route({
    method: 'POST',
    path: '/notifications/live-activity/push-to-start',
    summary: 'Compatibilité Live Activity locale',
    description: 'Accepte sans persister les tokens des anciennes versions iOS.',
    tags: ['notifications'],
  })
  .input(liveActivityPushToStartRegistrationSchema)
  .output(notificationRegistrationResponseSchema);
