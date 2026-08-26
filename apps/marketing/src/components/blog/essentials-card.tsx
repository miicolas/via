import { LineBadge } from "@/components/ui/line-badge";
import { TransitText } from "@/components/ui/transit-text";
import { transitLines } from "@/constants/transit";
import type { ArticleFrontmatter } from "@/lib/blog/schema";
import { formatLongDate, type ArticleStatus } from "@/lib/blog/status";
import { StatusBadge } from "./status-badge";
import { BusFront, CalendarRange, Scissors } from "lucide-react";
import type { ReactNode } from "react";

/**
 * L’encadré de tête : les dates, le tronçon, la solution de report.
 *
 * Rien ici n’est écrit à la main. Tout est dérivé du frontmatter, ce qui est le
 * seul moyen d’avoir la garantie que l’encadré et l’article disent la même
 * chose — et que le jour où une date bouge, elle bouge à un seul endroit.
 */
export function EssentialsCard({
  frontmatter,
  status,
}: {
  readonly frontmatter: ArticleFrontmatter;
  readonly status: ArticleStatus;
}): ReactNode {
  const sections = frontmatter.impactedSections;

  return (
    <section
      aria-label="L’essentiel"
      className="my-8 rounded-3xl border border-foreground/10 bg-muted/60 p-6 sm:p-7"
    >
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 className="text-xs font-semibold tracking-[0.1em] text-muted-foreground uppercase">
          L’essentiel
        </h2>
        <StatusBadge status={status} />
      </div>

      <div className="mt-5 flex flex-wrap items-center gap-2">
        {frontmatter.lines.map((key) => (
          <LineBadge
            key={key}
            line={transitLines[key]}
            className="size-8 rounded-[0.55rem] text-sm"
          />
        ))}
      </div>

      <dl className="mt-5 space-y-4">
        <Row icon={<CalendarRange className="size-4" aria-hidden="true" />} term="Période">
          {period(frontmatter)}
          {frontmatter.datesProvisional && (
            <span className="mt-1 block text-sm text-muted-foreground">
              Date non confirmée par l’exploitant à ce jour.
            </span>
          )}
        </Row>

        {sections.length > 0 && (
          <Row icon={<Scissors className="size-4" aria-hidden="true" />} term="Ce qui est coupé">
            <ul className="space-y-1">
              {sections.map((section, index) => (
                <li key={`${section.line}-${index}`}>
                  <TransitText>
                    {section.only !== undefined
                      ? `${section.only} : les rames passent sans s’arrêter`
                      : `${section.from ?? ""} – ${section.to ?? ""}`}
                  </TransitText>
                </li>
              ))}
            </ul>
          </Row>
        )}

        {frontmatter.substitution.length > 0 && (
          <Row icon={<BusFront className="size-4" aria-hidden="true" />} term="Comment faire">
            <ul className="space-y-1">
              {frontmatter.substitution.map((option) => (
                <li key={option}>
                  <TransitText>{option}</TransitText>
                </li>
              ))}
            </ul>
          </Row>
        )}
      </dl>
    </section>
  );
}

/** « du 22 juillet 2026 à avril 2027 » ne s’écrit pas comme « à partir du … ». */
function period(frontmatter: ArticleFrontmatter): string {
  const from = formatLongDate(frontmatter.validFrom);
  if (!frontmatter.validUntil) return `À partir du ${from}`;
  return `Du ${from} au ${formatLongDate(frontmatter.validUntil)}`;
}

function Row({
  icon,
  term,
  children,
}: {
  readonly icon: ReactNode;
  readonly term: string;
  readonly children: ReactNode;
}): ReactNode {
  return (
    <div className="grid grid-cols-[1.5rem_1fr] gap-x-3 gap-y-1">
      <span className="mt-0.5 text-muted-foreground">{icon}</span>
      <dt className="text-sm font-medium text-muted-foreground">{term}</dt>
      <dd className="col-start-2 leading-7 text-foreground">{children}</dd>
    </div>
  );
}
