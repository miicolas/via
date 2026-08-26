import { LineBadge } from "@/components/ui/line-badge";
import { transitLines } from "@/constants/transit";
import type { ArticleSummary } from "@/lib/blog/loader";
import { formatLongDate } from "@/lib/blog/status";
import { StatusBadge } from "./status-badge";
import Link from "next/link";
import type { ReactNode } from "react";

/**
 * Une entrée de la rubrique « Travaux & trafic ».
 *
 * Toute la carte est cliquable — c’est un lien, pas une div avec un
 * gestionnaire — pour que le clavier, le clic milieu et « ouvrir dans un
 * nouvel onglet » fonctionnent sans qu’on ait à les prévoir.
 */
export function ArticleCard({
  summary,
}: {
  readonly summary: ArticleSummary;
}): ReactNode {
  const { frontmatter, status, slug } = summary;

  return (
    <li>
      <Link
        href={`/blog/${slug}`}
        className="focus-ring group block rounded-2xl bg-frame p-5 transition-colors hover:bg-muted sm:p-6"
      >
        <div className="flex flex-wrap items-center gap-2">
          {frontmatter.lines.map((key) => (
            <LineBadge
              key={key}
              line={transitLines[key]}
              className="size-7 rounded-[0.5rem] text-xs"
            />
          ))}
          <StatusBadge status={status} className="ml-1" />
        </div>

        {/* Titre et chapô restent du texte : les logos sont déjà au-dessus. */}
        <h3 className="mt-4 text-xl leading-snug font-medium tracking-tight text-balance text-foreground">
          {frontmatter.title}
        </h3>

        <p className="mt-2 leading-7 text-muted-foreground">{frontmatter.description}</p>

        <p className="mt-4 text-sm text-muted-foreground">
          {formatLongDate(frontmatter.publishedAt)}
        </p>
      </Link>
    </li>
  );
}
