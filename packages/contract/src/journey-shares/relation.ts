import { oc } from "@orpc/contract";

import {
  journeyShareCreateInputSchema,
  journeyShareCreateResponseSchema,
  journeyShareGetInputSchema,
  journeyShareResponseSchema,
} from "./schema";

export const journeyShareCreateRelation = oc
  .route({
    method: "POST",
    path: "/journeys/shares",
    summary: "Créer un lien de partage de trajet",
    description:
      "Conserve le trajet choisi sous forme de snapshot immuable et retourne un lien web partageable.",
    tags: ["journey-shares"],
  })
  .input(journeyShareCreateInputSchema)
  .output(journeyShareCreateResponseSchema);

/** The app-only read path; the marketing site uses its narrowed public projection. */
export const journeyShareGetRelation = oc
  .route({
    method: "GET",
    path: "/journeys/shares",
    summary: "Lire un trajet partagé",
    description:
      "Retourne un snapshot de trajet partagé identifié par son token opaque.",
    tags: ["journey-shares"],
  })
  .input(journeyShareGetInputSchema)
  .output(journeyShareResponseSchema);
