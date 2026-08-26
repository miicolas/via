import type { ArticleDeclaredStop, ArticleImpactedSection } from "./schema";
import lineSchemas from "@/data/line-schemas.json";
import { transitLines } from "@/constants/transit";

/**
 * La géométrie des lignes, figée au build par `bun run snapshot:line-schemas`.
 *
 * Le schéma d’une ligne est l’illustration principale d’un article, et il doit
 * se dessiner avant que quoi que ce soit ne soit récupéré : le site s’endort
 * entre deux visites, l’API aussi, et une page dont le diagramme n’apparaît
 * qu’en cas de succès réseau est une page que Googlebot peut trouver vide.
 * Ce qui vit — ce qui est coupé aujourd’hui — se pose par-dessus.
 */

interface SnapshotStop {
  readonly id: string;
  readonly name: string;
  readonly isInterchange: boolean;
}

interface SnapshotSection {
  readonly role: "trunk" | "branch";
  readonly label?: string;
  readonly stops: readonly SnapshotStop[];
}

interface SnapshotLine {
  readonly id: string;
  readonly mode: string;
  readonly shortName: string;
  readonly color: string;
  readonly textColor: string;
  readonly directions: ReadonlyArray<{
    readonly directionId: number;
    readonly label: string;
    readonly sections: readonly SnapshotSection[];
  }>;
}

const snapshot = lineSchemas as { lines: readonly SnapshotLine[] };

export type StopState = "served" | "closed";

export interface StripStop {
  readonly name: string;
  readonly isInterchange: boolean;
  readonly state: StopState;
  /** Libellé de la branche qui commence à cet arrêt, le cas échéant. */
  readonly sectionLabel?: string;
  /**
   * Cet arrêt ouvre une nouvelle section — donc le rail ne doit pas le relier
   * au précédent. Aplatir une ligne à branches met bout à bout deux stations
   * qui ne se touchent pas (sur la 13, Guy Môquet et Les Courtilles) ; les
   * relier d’un trait plein serait un mensonge dessiné.
   */
  readonly startsSection?: boolean;
}

/** Ce qui a été escamoté entre deux morceaux de bande. */
export interface StripGap {
  readonly hidden: number;
  /** Le terminus, quand la coupure est au bord de la ligne. */
  readonly terminus?: string;
}

export interface StripSegment {
  readonly stops: readonly StripStop[];
  /** `cut[i]` vaut vrai quand le tronçon entre `stops[i]` et `stops[i+1]` est coupé. */
  readonly cut: readonly boolean[];
  readonly gapBefore?: StripGap;
  readonly gapAfter?: StripGap;
}

export interface LineStrip {
  readonly shortName: string;
  readonly color: string;
  readonly textColor: string;
  /** Toute la ligne, pour la vignette de partage et les tests. */
  readonly stops: readonly StripStop[];
  readonly cut: readonly boolean[];
  /** Ce qui est réellement dessiné : la ligne entière, ou ses zones utiles. */
  readonly segments: readonly StripSegment[];
  /**
   * Les branches traversées par la bande, dans l’ordre. Elles vont en légende
   * et non au-dessus des arrêts : « Branches Versailles Rive Droite /
   * Saint-Nom-la-Bretèche - Forêt de Marly » ne tiendra jamais au-dessus d’une
   * colonne de 96 pixels.
   */
  readonly branches: readonly string[];
  /** Une phrase décrivant l’impact, pour qui n’en voit pas le dessin. */
  readonly description: string;
}

/**
 * En deçà de ce nombre d’arrêts, la ligne se dessine entière : il n’y a rien à
 * gagner à escamoter quatre stations.
 */
const FULL_LINE_THRESHOLD = 14;

/** Combien d’arrêts de contexte autour d’une zone fermée. */
const CONTEXT = 3;

/**
 * Deux fermetures séparées par moins que ça se lisent comme une seule zone —
 * les recoller évite un « … 2 stations » qui n’apprend rien.
 */
const MERGE_DISTANCE = 3;

/** « Porte de Clichy, Mairie de Clichy et Les Courtilles » — la règle est celle du français, pas la nôtre. */
const FRENCH_LIST = new Intl.ListFormat("fr", { type: "conjunction" });

/**
 * Les noms de stations s’écrivent avec des tirets, des apostrophes et des
 * accents qui varient d’une source à l’autre. On compare des formes réduites,
 * jamais les chaînes brutes.
 */
function normalise(name: string): string {
  return name
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

/**
 * Une ligne du référentiel, aplatie en une bande lisible : les sections de la
 * direction 0 mises bout à bout, les branches gardant leur nom.
 *
 * Aplatir une ligne à branches est une simplification assumée. La 13 se lit
 * « Saint-Denis – Université … Châtillon … Les Courtilles » alors qu’aucune
 * rame ne fait ce trajet — mais c’est la façon dont les plans de quai la
 * dessinent, et le libellé de branche dit où la fourche se trouve.
 */
function stopsFromSnapshot(lineKey: keyof typeof transitLines): StripStop[] | null {
  const reference = transitLines[lineKey];
  const line = snapshot.lines.find(
    (candidate) =>
      candidate.mode === reference.mode && candidate.shortName === reference.shortName,
  );
  const direction = line?.directions[0];
  if (!direction) return null;

  const stops: StripStop[] = [];
  for (const section of direction.sections) {
    section.stops.forEach((stop, index) => {
      const opensSection = index === 0 && stops.length > 0;
      stops.push({
        name: stop.name,
        isInterchange: stop.isInterchange,
        state: "served",
        ...(index === 0 && section.label !== undefined ? { sectionLabel: section.label } : {}),
        ...(opensSection ? { startsSection: true } : {}),
      });
    });
  }

  return stops.length > 0 ? stops : null;
}

function stopsFromDeclaration(declared: readonly ArticleDeclaredStop[]): StripStop[] {
  return declared.map((stop) => ({
    name: stop.name,
    isInterchange: stop.isInterchange ?? false,
    state: "served" as const,
  }));
}

export class LineStripError extends Error {}

/**
 * La bande à dessiner pour une ligne d’un article.
 *
 * Une station nommée dans le frontmatter mais introuvable sur la ligne lève
 * une erreur, qui casse le build. C’est délibéré : un schéma qui ne surligne
 * rien parce qu’un nom a été mal orthographié se publie sans que personne ne
 * s’en aperçoive, et il ment au lecteur avec l’autorité d’un dessin.
 */
export function buildLineStrip({
  line,
  impactedSections,
  declaredStops = [],
}: {
  line: keyof typeof transitLines;
  impactedSections: readonly ArticleImpactedSection[];
  declaredStops?: readonly ArticleDeclaredStop[];
}): LineStrip {
  const reference = transitLines[line];
  const base = declaredStops.length > 0 ? stopsFromDeclaration(declaredStops) : stopsFromSnapshot(line);

  if (!base) {
    throw new LineStripError(
      `La ligne « ${line} » n’est pas dans l’instantané du réseau. Regénérez-le avec ` +
        `\`bun run snapshot:line-schemas\`, ou déclarez ses stations dans « declaredStops » ` +
        `si elle n’a pas encore ouvert.`,
    );
  }

  const stops = base.map((stop) => ({ ...stop }));
  const cut = new Array<boolean>(Math.max(0, stops.length - 1)).fill(false);
  const indexOf = new Map(stops.map((stop, index) => [normalise(stop.name), index]));

  const impacts = impactedSections.filter((section) => section.line === line);
  const phrases: string[] = [];

  for (const impact of impacts) {
    if (impact.only) {
      const index = resolve(indexOf, impact.only, line);
      stops[index] = { ...stops[index]!, state: "closed" };
      // Les rames traversent sans s’arrêter : le tronçon n’est pas coupé.
      phrases.push(`${impact.only} n’est pas desservie`);
      continue;
    }

    if (impact.from === undefined || impact.to === undefined) continue;

    const from = resolve(indexOf, impact.from, line);
    const to = resolve(indexOf, impact.to, line);
    const [start, end] = from <= to ? [from, to] : [to, from];

    for (let index = start; index <= end; index += 1) {
      stops[index] = { ...stops[index]!, state: "closed" };
    }
    for (let index = start; index < end; index += 1) {
      // Pas de tronçon entre deux sections : il n’y a pas de voie là.
      if (stops[index + 1]?.startsSection === true) continue;
      cut[index] = true;
    }
    phrases.push(`le tronçon ${impact.from} – ${impact.to} est interrompu`);
  }

  return {
    shortName: reference.shortName,
    color: reference.color,
    textColor: reference.textColor,
    stops,
    cut,
    segments: segmentsAround(stops, cut),
    branches: [
      ...new Set(stops.flatMap((stop) => (stop.sectionLabel ? [stop.sectionLabel] : []))),
    ],
    description:
      phrases.length === 0
        ? `Schéma de la ligne ${reference.shortName}, aucun tronçon interrompu.`
        : `Ligne ${reference.shortName} : ${FRENCH_LIST.format(phrases)}.`,
  };
}

/**
 * Ce qu’on dessine réellement.
 *
 * Une ligne de métro fait quarante stations, et une bande de quarante stations
 * s’ouvre sur son terminus — c’est-à-dire à l’opposé de ce que le lecteur est
 * venu voir. On garde donc les zones fermées avec quelques arrêts de contexte
 * de chaque côté, et on dit combien de stations ont été escamotées. La ligne
 * courte, ou celle qui n’a rien de fermé, se dessine entière.
 */
function segmentsAround(
  stops: readonly StripStop[],
  cut: readonly boolean[],
): StripSegment[] {
  const closed = stops.flatMap((stop, index) => (stop.state === "closed" ? [index] : []));
  if (closed.length === 0 || stops.length <= FULL_LINE_THRESHOLD) {
    return [{ stops, cut }];
  }

  // Fenêtres autour de chaque zone fermée, recollées quand elles se touchent.
  const windows: Array<{ start: number; end: number }> = [];
  for (const index of closed) {
    const start = Math.max(0, index - CONTEXT);
    const end = Math.min(stops.length - 1, index + CONTEXT);
    const previous = windows[windows.length - 1];

    if (previous && start - previous.end <= MERGE_DISTANCE) previous.end = Math.max(previous.end, end);
    else windows.push({ start, end });
  }

  return windows.map((window, index) => {
    const previous = windows[index - 1];
    const next = windows[index + 1];

    const hiddenBefore = previous ? window.start - previous.end - 1 : window.start;
    const hiddenAfter = next ? 0 : stops.length - 1 - window.end;

    return {
      stops: stops.slice(window.start, window.end + 1),
      cut: cut.slice(window.start, window.end),
      ...(hiddenBefore > 0
        ? {
            gapBefore: {
              hidden: hiddenBefore,
              ...(previous ? {} : { terminus: stops[0]?.name ?? "" }),
            },
          }
        : {}),
      ...(hiddenAfter > 0
        ? {
            gapAfter: {
              hidden: hiddenAfter,
              terminus: stops[stops.length - 1]?.name ?? "",
            },
          }
        : {}),
    } satisfies StripSegment;
  });
}

function resolve(
  indexOf: ReadonlyMap<string, number>,
  name: string,
  line: string,
): number {
  const index = indexOf.get(normalise(name));
  if (index === undefined) {
    throw new LineStripError(
      `La station « ${name} » est introuvable sur la ligne « ${line} ». Vérifiez son ` +
        `orthographe dans le frontmatter, telle qu’elle apparaît dans le référentiel.`,
    );
  }
  return index;
}
