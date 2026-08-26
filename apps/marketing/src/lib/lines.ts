import {
  publicLineDetailSchema,
  publicLineStatusesSchema,
  type PublicLineDetail,
  type PublicLineDisruption,
  type PublicLineStatus,
} from "@via/contract/public";

import { readValidated } from "@/lib/api";
import { transitLines } from "@/constants/transit";

/**
 * L’état des lignes, tel que l’API le laisse voir au site.
 *
 * C’est une surcouche, jamais un socle. Les pages du blog dessinent leurs
 * schémas depuis l’instantané commité et calculent leur badge d’état depuis le
 * frontmatter ; ce qui vient d’ici ne fait qu’ajouter ce qui se passe
 * aujourd’hui. Toute panne se solde donc par `null`, et une page qui perd son
 * bandeau reste juste et complète.
 *
 * Les formes viennent de `@via/contract/public`, la même déclaration que la
 * projection de l’API produit, et sont validées à la lecture : un champ renommé
 * d’un côté fait échouer le parse au lieu d’arriver `undefined` dans le rendu.
 */

export type LineCondition = PublicLineStatus;
export type LineDisruption = PublicLineDisruption;
export type LineDetail = PublicLineDetail;

/** Cinq minutes : c’est la raison d’être d’une page « hub » d’être à jour. */
export const HUB_REVALIDATE = 300;
/** Trente minutes sur un article : le bloc vivant y est une courtoisie. */
export const ARTICLE_REVALIDATE = 1_800;

/**
 * Toujours `HUB_REVALIDATE`, quelle que soit la page qui appelle. Le cache de
 * `fetch` de Next indexe par URL *et* par options : demander le même
 * `/public/lines/statuses` sous deux fenêtres en ferait deux entrées, revalidées
 * chacune de son côté pour la même réponse. Une seule fenêtre, la plus serrée,
 * et l’article lit gratuitement ce que le hub vient de rafraîchir.
 */
export async function fetchLineConditions(): Promise<readonly LineCondition[] | null> {
  const statuses = await readValidated(
    "/public/lines/statuses",
    HUB_REVALIDATE,
    publicLineStatusesSchema,
  );
  if (!statuses || statuses.source === "unavailable") return null;
  return statuses.lines;
}

/**
 * L’état d’une ligne du référentiel du site (`m13`, `rerB`…). Le rapprochement
 * se fait sur le mode et le numéro, jamais sur un identifiant IDFM écrit en
 * dur : les identifiants changent d’un import à l’autre, « métro 13 » non.
 */
export async function fetchLineCondition(
  key: keyof typeof transitLines,
): Promise<LineCondition | null> {
  const reference = transitLines[key];
  const conditions = await fetchLineConditions();
  return (
    conditions?.find(
      (line) => line.mode === reference.mode && line.shortName === reference.shortName,
    ) ?? null
  );
}

export async function fetchLineDetail(
  key: keyof typeof transitLines,
  revalidate: number = HUB_REVALIDATE,
): Promise<LineDetail | null> {
  const condition = await fetchLineCondition(key);
  if (!condition) return null;

  const detail = await readValidated(
    `/public/lines/detail?lineId=${encodeURIComponent(condition.id)}`,
    revalidate,
    publicLineDetailSchema,
  );
  return detail?.source === "live" ? detail : null;
}
