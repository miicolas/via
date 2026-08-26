import { ArticleCard } from "@/components/blog/article-card";
import { LiveLineStatus } from "@/components/blog/live-line-status";
import { transitLines } from "@/constants/transit";
import { articlesForLine, listCoveredLines } from "@/lib/blog/loader";
import { parisToday } from "@/lib/blog/status";
import type { ArticleLineKey } from "@/lib/blog/schema";
import { fetchLineCondition } from "@/lib/lines";
import { createPageMetadata } from "@/lib/metadata";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import Link from "next/link";
import type { ReactNode } from "react";

/**
 * La page d’une ligne : tout ce que le blog a écrit sur elle, plus son état
 * du jour.
 *
 * C’est l’actif durable de la rubrique. Un article sur les travaux d’août se
 * périme en septembre ; « travaux ligne 13 » se cherche tous les ans. Le hub
 * capte cette requête-là, ne périme jamais, et recycle vers les articles
 * récents l’autorité accumulée par les anciens.
 */
// Littéral : voir la note de `[slug]/page.tsx`.
export const revalidate = 300;
export const dynamicParams = false;

export async function generateStaticParams(): Promise<Array<{ line: string }>> {
  const lines = await listCoveredLines();
  return lines.map((line) => ({ line }));
}

function asLineKey(value: string): ArticleLineKey | null {
  return value in transitLines ? (value as ArticleLineKey) : null;
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ line: string }>;
}): Promise<Metadata> {
  const { line } = await params;
  const key = asLineKey(line);
  if (!key) return {};

  const reference = transitLines[key];
  const label = reference.mode === "rer" ? `RER ${reference.shortName}` : `ligne ${reference.shortName}`;

  return createPageMetadata({
    title: `Travaux ${label} : l’état du trafic et les chantiers en cours`,
    description: `Tous les travaux et perturbations de la ${label} suivis par Metyro : dates, stations fermées, solutions de report et état du trafic aujourd’hui.`,
    path: `/blog/ligne/${key}`,
  });
}

export default async function LineHubPage({
  params,
}: {
  params: Promise<{ line: string }>;
}): Promise<ReactNode> {
  const { line } = await params;
  const key = asLineKey(line);
  if (!key) notFound();

  const reference = transitLines[key];
  const today = parisToday();
  const [{ current, archived }, condition] = await Promise.all([
    articlesForLine(key, today),
    fetchLineCondition(key),
  ]);

  if (current.length === 0 && archived.length === 0) notFound();

  const label =
    reference.mode === "rer" ? `RER ${reference.shortName}` : `Ligne ${reference.shortName}`;

  return (
    <main id="main-content" className="flex-1 px-6 py-16 sm:py-24">
      <div className="mx-auto max-w-3xl">
        <Link
          href="/blog"
          className="focus-ring text-sm text-muted-foreground transition-colors hover:text-foreground"
        >
          ← Travaux &amp; trafic
        </Link>

        <h1 className="mt-8 text-3xl leading-[1.1] font-medium tracking-tight text-balance sm:text-5xl">
          Travaux {label.toLowerCase()}
        </h1>
        <p className="mt-5 text-lg leading-8 text-muted-foreground">
          Les chantiers, fermetures et perturbations que nous suivons sur cette
          ligne, du plus récent au plus ancien.
        </p>

        {/* Absent quand l’API n’a pas répondu : la page reste entière sans lui. */}
        {condition && (
          <div className="mt-8">
            <LiveLineStatus line={key} condition={condition} />
          </div>
        )}

        {current.length > 0 && (
          <section aria-labelledby="en-cours" className="mt-14">
            <h2
              id="en-cours"
              className="text-xs font-semibold tracking-[0.1em] text-muted-foreground uppercase"
            >
              En cours et à venir
            </h2>
            <ul className="mt-5 space-y-3">
              {current.map((summary) => (
                <ArticleCard key={summary.slug} summary={summary} />
              ))}
            </ul>
          </section>
        )}

        {archived.length > 0 && (
          <section aria-labelledby="archive" className="mt-14">
            <h2
              id="archive"
              className="text-xs font-semibold tracking-[0.1em] text-muted-foreground uppercase"
            >
              Chantiers terminés
            </h2>
            <ul className="mt-5 space-y-3">
              {archived.map((summary) => (
                <ArticleCard key={summary.slug} summary={summary} />
              ))}
            </ul>
          </section>
        )}
      </div>
    </main>
  );
}
