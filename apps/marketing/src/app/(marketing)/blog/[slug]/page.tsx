import { ArticleToc } from "@/components/blog/article-toc";
import { EndedBanner } from "@/components/blog/ended-banner";
import { LiveLineStatus } from "@/components/blog/live-line-status";
import { StatusBadge } from "@/components/blog/status-badge";
import { Accordion } from "@/components/ui/accordion";
import { LineBadge } from "@/components/ui/line-badge";
import { transitLines } from "@/constants/transit";
import { findArticle, loadArticles } from "@/lib/blog/loader";
import { renderArticle } from "@/lib/blog/markdown";
import { articleStructuredData } from "@/lib/blog/structured-data";
import { articleStatus, formatLongDate, parisToday } from "@/lib/blog/status";
import { fetchLineCondition } from "@/lib/lines";
import { createArticleMetadata } from "@/lib/metadata";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import Link from "next/link";
import type { ReactNode } from "react";

/**
 * Les articles sont prérendus au build : leur contenu est un fichier du dépôt,
 * pas une requête. Le `revalidate` ne sert qu’au bloc d’état vivant, qui est la
 * seule chose de la page à pouvoir changer sans commit.
 */
// Littéral, et non `ARTICLE_REVALIDATE` : Next analyse statiquement les
// exports de configuration de segment et refuse une constante importée.
export const revalidate = 1800;
export const dynamicParams = false;

export async function generateStaticParams(): Promise<Array<{ slug: string }>> {
  const articles = await loadArticles();
  return articles.map((article) => ({ slug: article.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const article = await findArticle(slug);
  if (!article) return {};

  return createArticleMetadata({
    title: article.frontmatter.title,
    description: article.frontmatter.description,
    path: `/blog/${slug}`,
    publishedTime: article.frontmatter.publishedAt,
    ...(article.frontmatter.updatedAt === undefined
      ? {}
      : { modifiedTime: article.frontmatter.updatedAt }),
  });
}

export default async function ArticlePage({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<ReactNode> {
  const { slug } = await params;
  const article = await findArticle(slug);
  if (!article) notFound();

  const { frontmatter, body } = article;
  const today = parisToday();
  const status = articleStatus(frontmatter, today);

  const [{ content, headings }, condition] = await Promise.all([
    renderArticle({ body, frontmatter, today }),
    // La ligne principale de l’article. Toute panne se solde par `null`, et la
    // page se rend sans son bandeau plutôt que de ne pas se rendre.
    frontmatter.lines[0]
      ? fetchLineCondition(frontmatter.lines[0])
      : Promise.resolve(null),
  ]);

  return (
    <main id="main-content" className="flex-1 px-6 py-16 sm:py-24">
      <script
        type="application/ld+json"
        // Chaîne construite depuis le frontmatter validé, jamais depuis une entrée.
        dangerouslySetInnerHTML={{
          __html: JSON.stringify(articleStructuredData({ frontmatter, slug })),
        }}
      />

      <article className="mx-auto max-w-5xl">
        <header>
          <Link
            href="/blog"
            className="focus-ring text-sm text-muted-foreground transition-colors hover:text-foreground"
          >
            ← Travaux &amp; trafic
          </Link>

          <div className="mt-8 flex flex-wrap items-center gap-3">
            {frontmatter.lines.map((key) => (
              <LineBadge
                key={key}
                line={transitLines[key]}
                className="size-9 rounded-[0.6rem] text-base"
              />
            ))}
            <StatusBadge status={status} />
          </div>

          {/*
            Pas de `TransitText` sur le titre ni sur le chapô. Les logos de
            ligne se lisent bien dans du texte courant et détruisent un titre :
            cinq pastilles au milieu d’un H1 en cassent l’interligne et le
            rythme, et le lecteur ne voit plus la phrase. Le badge de ligne est
            déjà au-dessus, il suffit.
          */}
          <h1 className="mt-6 max-w-3xl text-3xl leading-[1.1] font-medium tracking-tight text-balance text-foreground sm:text-5xl">
            {frontmatter.title}
          </h1>

          <p className="mt-5 max-w-2xl text-lg leading-8 text-muted-foreground">
            {frontmatter.description}
          </p>

          <p className="mt-7 text-sm text-muted-foreground">
            Par l’équipe Metyro · Publié le {formatLongDate(frontmatter.publishedAt)}
            {frontmatter.updatedAt !== undefined &&
              ` · Mis à jour le ${formatLongDate(frontmatter.updatedAt)}`}
          </p>
        </header>

        <EndedBanner status={status} lines={frontmatter.lines} />

        <div className="mt-12 grid gap-12 lg:grid-cols-[1fr_220px] lg:gap-16">
          <div className="min-w-0">
            {condition && frontmatter.lines[0] && (
              <div className="mb-10">
                <LiveLineStatus line={frontmatter.lines[0]} condition={condition} />
              </div>
            )}

            {content}

            <section aria-labelledby="questions" className="mt-16">
              <h2
                id="questions"
                className="scroll-mt-32 text-2xl leading-tight font-medium tracking-tight sm:text-3xl"
              >
                Questions fréquentes
              </h2>
              <div className="mt-6">
                <Accordion items={frontmatter.faq} />
              </div>
            </section>
          </div>

          <aside className="order-first lg:order-last">
            <ArticleToc headings={headings} />
          </aside>
        </div>
      </article>
    </main>
  );
}
