import { BlurHeadlineSection } from "@/components/sections/blur-headline-section";
import { BlogClosingSection } from "@/components/sections/blog/blog-closing-section";
import { BlogHero } from "@/components/sections/blog/blog-hero";
import { JournalIndexSection } from "@/components/sections/blog/journal-index-section";
import { WorksIndexSection } from "@/components/sections/blog/works-index-section";
import { blogContent } from "@/constants/blog";
import { listArticleSummaries, listCoveredLines } from "@/lib/blog/loader";
import { createPageMetadata } from "@/lib/metadata";
import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = createPageMetadata({
  title: blogContent.metadata.title,
  description: blogContent.metadata.description,
  path: "/blog",
});

/**
 * Deux rubriques, dans cet ordre.
 *
 * « Travaux & trafic » est de l’information de service, datée et périssable ;
 * le Journal est de l’essai de marque, sans date. Elles n’ont ni le même ton,
 * ni le même lecteur, ni la même durée de vie, et c’est pourquoi elles ne
 * partagent que cette page.
 */
export default async function BlogPage(): Promise<ReactNode> {
  const [articles, lines] = await Promise.all([listArticleSummaries(), listCoveredLines()]);

  return (
    <main id="main-content" className="flex-1">
      <BlogHero content={blogContent.hero} />
      <WorksIndexSection articles={articles} lines={lines} />
      <BlurHeadlineSection text={blogContent.blurHeadline} />
      <JournalIndexSection content={blogContent.index} />
      <BlogClosingSection content={blogContent.closing} />
    </main>
  );
}
