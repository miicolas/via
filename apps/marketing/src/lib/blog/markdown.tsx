import { AlertCallout } from "@/components/blog/alert-callout";
import { EssentialsCard } from "@/components/blog/essentials-card";
import { LineStrip } from "@/components/blog/line-strip";
import { proseComponents } from "@/components/blog/prose";
import { SourcesBlock } from "@/components/blog/sources-block";
import { WorksPhases } from "@/components/blog/works-phases";
import { transitLines } from "@/constants/transit";
import { buildLineStrip } from "./line-strip-data";
import { remarkTransitAlerts, remarkTransitDirectives, type AlertVariant } from "./remark-transit";
import type { ArticleFrontmatter } from "./schema";
import { articleStatus } from "./status";
import type { Element, Root as HastRoot } from "hast";
import { toJsxRuntime } from "hast-util-to-jsx-runtime";
import type { ReactNode } from "react";
import { Fragment, jsx, jsxs } from "react/jsx-runtime";
import rehypeSlug from "rehype-slug";
import remarkDirective from "remark-directive";
import remarkGfm from "remark-gfm";
import remarkParse from "remark-parse";
import remarkRehype from "remark-rehype";
import { unified } from "unified";
import { visit } from "unist-util-visit";

export interface ArticleHeading {
  readonly id: string;
  readonly depth: 2 | 3;
  readonly text: string;
}

export interface RenderedArticle {
  readonly content: ReactNode;
  /** Les titres de niveau 2 et 3, pour le sommaire latéral. */
  readonly headings: readonly ArticleHeading[];
}

/**
 * Markdown → React, avec le vocabulaire du réseau.
 *
 * Le contenu reste du Markdown strict : aucun JSX dans les articles. C’est ce
 * qui permet à un brouillon d’être produit automatiquement — une directive
 * `::line-strip{line="m13"}` peut être émise sans risque, du JSX non — et ce
 * qui garde les fichiers relisibles par quelqu’un qui n’écrit pas de code.
 */
export async function renderArticle({
  body,
  frontmatter,
  today,
}: {
  body: string;
  frontmatter: ArticleFrontmatter;
  today: string;
}): Promise<RenderedArticle> {
  const headings: ArticleHeading[] = [];

  const processor = unified()
    .use(remarkParse)
    .use(remarkGfm)
    .use(remarkDirective)
    .use(remarkTransitAlerts)
    .use(remarkTransitDirectives)
    .use(remarkRehype)
    .use(rehypeSlug)
    .use(collectHeadings, headings);

  const tree = await processor.run(processor.parse(body));

  const content = toJsxRuntime(tree as HastRoot, {
    Fragment,
    jsx,
    jsxs,
    components: {
      ...proseComponents,
      ...articleComponents({ frontmatter, today }),
    } as never,
  });

  return { content, headings };
}

/**
 * Les composants qu’une directive peut appeler. Construits par article plutôt
 * qu’exportés une fois : une directive porte un nom de ligne, pas des données,
 * et c’est le frontmatter qui sait ce qu’il faut en faire.
 */
function articleComponents({
  frontmatter,
  today,
}: {
  frontmatter: ArticleFrontmatter;
  today: string;
}) {
  return {
    "transit-alert": ({
      variant,
      children,
    }: {
      readonly variant?: AlertVariant;
      readonly children?: ReactNode;
    }) => <AlertCallout {...(variant ? { variant } : {})}>{children}</AlertCallout>,

    "line-strip": ({ line }: { readonly line?: string }) => {
      const key = resolveLine(line) ?? frontmatter.lines[0];
      if (!key) return null;

      return (
        <LineStrip
          strip={buildLineStrip({
            line: key,
            impactedSections: frontmatter.impactedSections,
            declaredStops: frontmatter.declaredStops,
          })}
        />
      );
    },

    phases: () => <WorksPhases phases={frontmatter.phases} today={today} />,

    essentiel: () => (
      <EssentialsCard
        frontmatter={frontmatter}
        status={articleStatus(frontmatter, today)}
      />
    ),

    sources: () => (
      <SourcesBlock
        sources={frontmatter.sources}
        lastVerifiedAt={frontmatter.lastVerifiedAt}
      />
    ),
  };
}

function resolveLine(value: string | undefined): keyof typeof transitLines | undefined {
  if (value && value in transitLines) return value as keyof typeof transitLines;
  return undefined;
}

/**
 * Les titres, relevés après `rehype-slug` pour que le sommaire et les ancres
 * partagent forcément les mêmes identifiants — les recalculer serait la
 * garantie qu’ils divergent un jour.
 */
function collectHeadings(headings: ArticleHeading[]) {
  return (tree: HastRoot) => {
    visit(tree, "element", (node: Element) => {
      if (node.tagName !== "h2" && node.tagName !== "h3") return;

      const id = node.properties?.["id"];
      if (typeof id !== "string") return;

      headings.push({
        id,
        depth: node.tagName === "h2" ? 2 : 3,
        text: textOf(node),
      });
    });
  };
}

function textOf(node: Element): string {
  let text = "";
  visit(node, "text", (child: { value: string }) => {
    text += child.value;
  });
  return text.trim();
}
