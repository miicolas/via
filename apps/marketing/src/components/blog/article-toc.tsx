import type { ArticleHeading } from "@/lib/blog/markdown";
import type { ReactNode } from "react";

/**
 * Le sommaire d’un article, aux mêmes ancres que ses titres.
 *
 * Les identifiants viennent de `rehype-slug`, relevés à la volée pendant le
 * rendu : les recalculer ici serait la garantie qu’ils divergent un jour et
 * qu’un lien du sommaire ne mène nulle part.
 */
export function ArticleToc({
  headings,
}: {
  readonly headings: readonly ArticleHeading[];
}): ReactNode {
  // Un article de deux titres n’a pas besoin qu’on le résume.
  if (headings.length < 3) return null;

  return (
    <nav aria-label="Sommaire de l’article" className="lg:sticky lg:top-32">
      <p className="mb-4 font-mono text-xs font-semibold tracking-[0.1em] text-muted-foreground uppercase">
        Sur cette page
      </p>
      <ul className="space-y-1">
        {headings.map((heading) => (
          <li key={heading.id}>
            <a
              href={`#${heading.id}`}
              className={`focus-ring block min-h-11 rounded-xl py-2.5 text-sm text-muted-foreground transition-colors duration-150 hover:bg-frame hover:text-foreground ${
                heading.depth === 3 ? "pr-3 pl-6" : "px-3"
              }`}
            >
              {heading.text}
            </a>
          </li>
        ))}
      </ul>
    </nav>
  );
}
