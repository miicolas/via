import type { ArticleSource } from "@/lib/blog/schema";
import { formatLongDate } from "@/lib/blog/status";
import { ExternalLink } from "lucide-react";
import type { ReactNode } from "react";

/**
 * D’où viennent les faits, et quand un humain les a regardés.
 *
 * Un article de travaux se périme, et il est réécrit à partir de pages
 * officielles que le lecteur peut aller vérifier. Afficher la source et la
 * date de consultation est la seule garantie honnête qu’on puisse offrir :
 * elle dit « voici ce qui était affiché ce jour-là », pas « faites-nous
 * confiance ».
 *
 * L’attribution est portée ici quand la donnée en exige une — la Licence
 * Ouverte 2.0 d’Île-de-France Mobilités autorise la réutilisation commerciale
 * à cette seule condition.
 */
export function SourcesBlock({
  sources,
  lastVerifiedAt,
}: {
  readonly sources: readonly ArticleSource[];
  readonly lastVerifiedAt: string;
}): ReactNode {
  return (
    <section
      aria-labelledby="sources"
      className="mt-14 border-t border-foreground/10 pt-8"
    >
      <h2
        id="sources"
        className="text-xs font-semibold tracking-[0.1em] text-muted-foreground uppercase"
      >
        Sources
      </h2>

      <ul className="mt-4 space-y-3">
        {sources.map((source) => (
          <li key={source.url} className="leading-6">
            <a
              href={source.url}
              rel="nofollow noopener noreferrer"
              target="_blank"
              className="focus-ring inline-flex items-baseline gap-1.5 text-foreground underline decoration-foreground/25 underline-offset-4 transition-colors hover:decoration-foreground"
            >
              {source.label}
              <ExternalLink className="size-3 shrink-0 self-center" aria-hidden="true" />
            </a>
            <span className="text-muted-foreground">
              {" — "}
              {source.publisher}, consulté le {formatLongDate(source.consultedAt)}
            </span>
            {source.attribution !== undefined && (
              <span className="mt-0.5 block text-sm text-muted-foreground">
                {source.attribution}
              </span>
            )}
          </li>
        ))}
      </ul>

      <p className="mt-6 text-sm text-muted-foreground">
        Faits vérifiés le {formatLongDate(lastVerifiedAt)}. Les travaux évoluent :
        en cas de doute le jour même, l’information de l’exploitant fait foi.
      </p>
    </section>
  );
}
