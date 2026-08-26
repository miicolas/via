import { transitLines } from "@/constants/transit";
import { z } from "zod";

/**
 * L’en-tête d’un article de la rubrique « Travaux & trafic ».
 *
 * C’est le contrat entre la prose et les données. Tout ce qui est factuel et
 * répété — les dates, le tronçon coupé, la substitution — vit ici et nulle part
 * ailleurs : l’encadré « L’essentiel », le badge d’état, le schéma de ligne et
 * les données structurées en sont tous dérivés. Un rédacteur qui écrirait
 * « jusqu’au 24 août » dans un paragraphe créerait une seconde vérité, qui se
 * périmerait sans que rien ne le signale.
 *
 * Le vocabulaire reprend celui de `packages/contract/src/lines/schema.ts`
 * (`severity`, `periods`, `impactedSections`) pour qu’un jour un brouillon
 * puisse être pré-rempli depuis le flux sans traduction.
 */

/**
 * Un jour, en `AAAA-MM-JJ`.
 *
 * YAML transforme `2026-11-30` en `Date` de lui-même, et exiger des guillemets
 * autour de chaque date serait un piège pour tous ceux qui écriront un article
 * ensuite. On accepte donc les deux formes et on ramène tout au jour : la date
 * est lue en UTC par YAML, donc `toISOString()` rend bien le jour écrit.
 */
const isoDate = z
  .union([z.string(), z.date()])
  .transform((value) => (value instanceof Date ? value.toISOString().slice(0, 10) : value))
  .pipe(z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Une date s’écrit AAAA-MM-JJ."));

/** Les clés du référentiel de couleurs officielles : `m8`, `m13`, `rerB`… */
const lineKey = z.enum(
  Object.keys(transitLines) as [keyof typeof transitLines, ...Array<keyof typeof transitLines>],
);

/**
 * Ce qui est coupé, sous l’une de ses deux formes — et il faut les deux.
 *
 * Un tronçon interrompu (`from`/`to`) et une station traversée sans arrêt
 * (`only`) ne se dessinent pas pareil et ne veulent pas dire la même chose :
 * sur la ligne 8, les rames passent sous République sans s’y arrêter, et le
 * reste de la ligne roule normalement. Représenter ça comme un tronçon coupé
 * ferait croire à une interruption qui n’existe pas.
 */
const impactedSection = z
  .object({
    line: lineKey,
    /** Bornes du tronçon coupé, telles qu’elles s’écrivent sur les plans. */
    from: z.string().min(1).optional(),
    to: z.string().min(1).optional(),
    /** Une station traversée sans arrêt, le reste de la ligne circulant. */
    only: z.string().min(1).optional(),
  })
  .refine(
    (section) =>
      section.only !== undefined
        ? section.from === undefined && section.to === undefined
        : section.from !== undefined && section.to !== undefined,
    { message: "Renseignez soit « only », soit « from » et « to » — jamais les deux." },
  );

const phase = z.object({
  label: z.string().min(1),
  from: isoDate,
  to: isoDate,
  note: z.string().min(1).optional(),
});

const faqEntry = z.object({
  question: z.string().min(1),
  answer: z.string().min(1),
});

/**
 * Une source vérifiable. `consultedAt` n’est pas décoratif : il dit au lecteur
 * quand un humain a regardé la page officielle, ce qui est la seule garantie
 * honnête qu’un article sur des travaux puisse offrir.
 */
const source = z.object({
  label: z.string().min(1),
  url: z.url(),
  publisher: z.string().min(1),
  consultedAt: isoDate,
  /** Licence Ouverte 2.0 : l’attribution est obligatoire, on la porte. */
  attribution: z.string().min(1).optional(),
});

/**
 * Une station du schéma dessiné à la main, pour une ligne que le référentiel
 * ne connaît pas encore. La 18 ouvre le 30 novembre 2026 : elle n’est dans
 * aucun GTFS, donc dans aucun instantané, et un article sur son ouverture doit
 * pourtant montrer ses quatre gares.
 */
const declaredStop = z.object({
  name: z.string().min(1),
  isInterchange: z.boolean().optional(),
});

export const articleFrontmatterSchema = z.object({
  title: z.string().min(1).max(120),
  /** La méta-description : ce que Google affiche sous le titre. */
  description: z.string().min(1).max(200),
  kind: z.enum(["fermeture", "phases", "ouverture", "perturbation"]),
  lines: z.array(lineKey).min(1),
  severity: z.enum(["attention", "disrupted", "suspended"]).default("disrupted"),

  impactedSections: z.array(impactedSection).default([]),
  /** Le schéma à dessiner quand la ligne n’existe pas encore. */
  declaredStops: z.array(declaredStop).default([]),
  phases: z.array(phase).default([]),
  /** Solutions de report, en français : rendues via `TransitText`. */
  substitution: z.array(z.string().min(1)).default([]),

  validFrom: isoDate,
  /** Absent quand la fin n’est pas connue — c’est un fait, pas un oubli. */
  validUntil: isoDate.optional(),
  /** Vrai quand une date annoncée n’est pas encore confirmée officiellement. */
  datesProvisional: z.boolean().default(false),

  publishedAt: isoDate,
  updatedAt: isoDate.optional(),
  lastVerifiedAt: isoDate,

  faq: z.array(faqEntry).min(1, "Un article porte au moins une question fréquente."),
  sources: z.array(source).min(1, "Un article cite au moins une source."),
});

export type ArticleFrontmatter = z.infer<typeof articleFrontmatterSchema>;
export type ArticleLineKey = z.infer<typeof lineKey>;
export type ArticleImpactedSection = z.infer<typeof impactedSection>;
export type ArticlePhase = z.infer<typeof phase>;
export type ArticleSource = z.infer<typeof source>;
export type ArticleFaqEntry = z.infer<typeof faqEntry>;
export type ArticleDeclaredStop = z.infer<typeof declaredStop>;
