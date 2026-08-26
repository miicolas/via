import type { Blockquote, Paragraph, Root, Text } from "mdast";
import type { Plugin } from "unified";
import { visit } from "unist-util-visit";

/**
 * Les cinq façons dont un article interpelle son lecteur.
 *
 * La syntaxe est celle des alertes GitHub — `> [!TRAVAUX]` — mais le
 * vocabulaire est celui du réseau, pas celui d’un dépôt de code. Un voyageur
 * qui parcourt la page en diagonale doit repérer « bus de substitution » d’un
 * coup d’œil ; `[!WARNING]` en gris ne fait pas ça.
 */
export const ALERT_VARIANTS = [
  "travaux",
  "perturbation",
  "substitution",
  "note",
  "astuce",
] as const;

export type AlertVariant = (typeof ALERT_VARIANTS)[number];

const ALERT_MARKER = /^\[!([A-ZÉÀ-Ü-]+)\]\s*/u;

function asVariant(raw: string): AlertVariant | null {
  const normalised = raw
    .toLowerCase()
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "");
  return (ALERT_VARIANTS as readonly string[]).includes(normalised)
    ? (normalised as AlertVariant)
    : null;
}

/**
 * `> [!TRAVAUX]` en tête d’une citation la transforme en encadré typé. Le
 * marqueur est retiré du texte : il pilote le rendu, il ne se lit pas.
 *
 * Une citation dont le marqueur n’est pas reconnu reste une citation — un
 * article ne doit pas perdre un paragraphe parce qu’une alerte a été mal
 * orthographiée.
 */
export const remarkTransitAlerts: Plugin<[], Root> = () => (tree) => {
  visit(tree, "blockquote", (node: Blockquote) => {
    const paragraph: Paragraph | undefined =
      node.children[0]?.type === "paragraph" ? node.children[0] : undefined;
    if (!paragraph) return;

    const first: Text | undefined =
      paragraph.children[0]?.type === "text" ? paragraph.children[0] : undefined;
    if (!first) return;

    const match = ALERT_MARKER.exec(first.value);
    if (!match?.[1]) return;

    const variant = asVariant(match[1]);
    if (!variant) return;

    first.value = first.value.slice(match[0].length);
    // Le marqueur occupait sa propre ligne : la citation commence après.
    if (first.value.startsWith("\n")) {
      first.value = first.value.replace(/^\n+/, "");
    }
    if (first.value === "" && paragraph.children.length > 1) {
      paragraph.children.shift();
    }

    node.data = {
      ...node.data,
      hName: "transit-alert",
      hProperties: { variant },
    };
  });
};

/** Les composants qu’un article peut appeler depuis sa prose. */
const DIRECTIVES = new Set(["line-strip", "phases", "essentiel", "sources"]);

/**
 * La part d’un nœud de directive que ce greffon touche. Déclarée ici plutôt
 * qu’importée de `mdast-util-directive` : les types de directives arrivent par
 * augmentation de module, et cette augmentation n’est visible que là où
 * `remark-directive` est lui-même importé.
 */
interface DirectiveNode {
  name: string;
  attributes?: Record<string, string | null | undefined> | null | undefined;
  data?: Record<string, unknown> | undefined;
}

/**
 * `::line-strip{line="m13"}` et consorts, rendus comme des éléments dont le
 * nom porte un tiret — ce qui les rend impossibles à confondre avec du HTML.
 *
 * Une directive inconnue est laissée telle quelle plutôt que rendue vide : au
 * build, elle apparaîtra en toutes lettres dans la page, ce qui est le signal
 * le plus court possible qu’un nom a été mal écrit.
 */
export const remarkTransitDirectives: Plugin<[], Root> = () => (tree) => {
  visit(tree, ["leafDirective", "containerDirective"], (node) => {
    const directive = node as unknown as DirectiveNode;
    if (!DIRECTIVES.has(directive.name)) return;

    const properties: Record<string, string> = {};
    for (const [key, value] of Object.entries(directive.attributes ?? {})) {
      if (typeof value === "string") properties[key] = value;
    }

    directive.data = {
      ...directive.data,
      hName: directive.name,
      hProperties: properties,
    };
  });
};
