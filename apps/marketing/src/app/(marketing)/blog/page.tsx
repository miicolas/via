import { BlurHeadlineSection } from "@/components/sections/blur-headline-section";
import { BlogClosingSection } from "@/components/sections/blog/blog-closing-section";
import { BlogHero } from "@/components/sections/blog/blog-hero";
import { JournalIndexSection } from "@/components/sections/blog/journal-index-section";
import { blogContent } from "@/constants/blog";
import { createPageMetadata } from "@/lib/metadata";
import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = createPageMetadata({
  title: blogContent.metadata.title,
  description: blogContent.metadata.description,
  path: "/blog",
});

export default function BlogPage(): ReactNode {
  return (
    <main id="main-content" className="flex-1">
      <BlogHero content={blogContent.hero} />
      <BlurHeadlineSection text={blogContent.blurHeadline} />
      <JournalIndexSection content={blogContent.index} />
      <BlogClosingSection content={blogContent.closing} />
    </main>
  );
}
