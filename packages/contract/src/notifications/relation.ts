import { oc } from "@orpc/contract";

import {
  liveActivityPushToStartRegistrationSchema,
  liveActivityRegistrationSchema,
  liveActivityUnregistrationSchema,
  activeJourneyRegistrationSchema,
  activeJourneyUnregistrationSchema,
  notificationDeviceRegistrationSchema,
  notificationDeviceUnregistrationSchema,
  notificationRegistrationResponseSchema,
  notificationRemovalResponseSchema,
} from "./schema";

export const notificationsRegisterActiveJourneyRelation = oc
  .route({
    method: "POST",
    path: "/notifications/active-journey",
    summary: "Enregistrer un trajet actif pour les perturbations",
    description:
      "Associe une installation authentifiée à la fenêtre et aux lignes d’un trajet suivi.",
    tags: ["notifications"],
  })
  .input(activeJourneyRegistrationSchema)
  .output(notificationRegistrationResponseSchema);

export const notificationsUnregisterActiveJourneyRelation = oc
  .route({
    method: "POST",
    path: "/notifications/active-journey/unregister",
    summary: "Désinscrire un trajet actif",
    description: "Supprime l’abonnement de perturbations d’un trajet terminé.",
    tags: ["notifications"],
  })
  .input(activeJourneyUnregistrationSchema)
  .output(notificationRemovalResponseSchema);

export const notificationsRegisterDeviceRelation = oc
  .route({
    method: "POST",
    path: "/notifications/device",
    summary: "Enregistrer un appareil pour les notifications",
    description: "Associe le token APNs de l’installation au compte courant.",
    tags: ["notifications"],
  })
  .input(notificationDeviceRegistrationSchema)
  .output(notificationRegistrationResponseSchema);

export const notificationsUnregisterDeviceRelation = oc
  .route({
    method: "POST",
    path: "/notifications/device/unregister",
    summary: "Désinscrire un appareil des notifications",
    description:
      "Supprime les tokens de l’installation pour le compte courant.",
    tags: ["notifications"],
  })
  .input(notificationDeviceUnregistrationSchema)
  .output(notificationRemovalResponseSchema);

export const notificationsRegisterActivityRelation = oc
  .route({
    method: "POST",
    path: "/notifications/live-activity",
    summary: "Enregistrer une Live Activity",
    description: "Associe un token ActivityKit à un trajet actif.",
    tags: ["notifications"],
  })
  .input(liveActivityRegistrationSchema)
  .output(notificationRegistrationResponseSchema);

export const notificationsUnregisterActivityRelation = oc
  .route({
    method: "POST",
    path: "/notifications/live-activity/unregister",
    summary: "Désinscrire une Live Activity",
    description: "Supprime le token ActivityKit d’un trajet terminé.",
    tags: ["notifications"],
  })
  .input(liveActivityUnregistrationSchema)
  .output(notificationRemovalResponseSchema);

export const notificationsRegisterPushToStartRelation = oc
  .route({
    method: "POST",
    path: "/notifications/live-activity/push-to-start",
    summary: "Enregistrer le token de démarrage Live Activity",
    description: "Autorise le serveur à démarrer une Live Activity à distance.",
    tags: ["notifications"],
  })
  .input(liveActivityPushToStartRegistrationSchema)
  .output(notificationRegistrationResponseSchema);
