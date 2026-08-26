import { ArticleCard } from "@/components/blog/article-card";
import { LineBadge } from "@/components/ui/line-badge";
import { SectionHeading } from "@/components/ui/section-heading";
import { transitLines } from "@/constants/transit";
import type { ArticleSummary } from "@/lib/blog/loader";
import type { ArticleLineKey } from "@/lib/blog/schema";
import Link from "next/link";
import type { ReactNode } from "react";

/**
 * La rubrique « Travaux & trafic », en tête du sommaire du blog.
 *
 * Elle est tenue à l’écart du Journal, et visiblement : mélanger un essai sur
 * République et « Travaux ligne 13 : ce qui change » dans un même flux dessert
 * les deux. Le lecteur pressé ne trouve pas son information, et Google ne sait
 * plus ce qu’est cette page.
 */
export function WorksIndexSection({
  articles,
  lines,
}: {
  readonly articles: readonly ArticleSummary[];
  readonly lines: readonly ArticleLineKey[];
}): ReactNode {
  if (articles.length === 0) return null;

  return (
    <section id="travaux" className="w-full scroll-mt-32 px-6 py-20 sm:py-28">
      <div className="mx-auto max-w-5xl">
        <SectionHeading
          eyebrow="Travaux & trafic"
          title="Ce qui change sur le réseau"
          description="Les fermetures, les chantiers et les ouvertures de lignes, avec leurs dates, leurs stations et ce qu’il faut faire à la place."
          width="wide"
        />

        {lines.length > 0 && (
          <nav aria-label="Lignes suivies" className="mb-8 flex flex-wrap items-center gap-2">
            {lines.map((key) => (
              <Link
                key={key}
                href={`/blog/ligne/${key}`}
                className="focus-ring rounded-full transition-transform hover:scale-105"
                aria-label={`Travaux de la ligne ${transitLines[key].shortName}`}
              >
                <LineBadge
                  line={transitLines[key]}
                  className="size-9 rounded-[0.6rem] text-base"
                />
              </Link>
            ))}
          </nav>
        )}

        <ul className="space-y-3">
          {articles.map((summary) => (
            <ArticleCard key={summary.slug} summary={summary} />
          ))}
        </ul>
      </div>
    </section>
  );
}
