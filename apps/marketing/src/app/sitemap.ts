import { project } from "@/constants/project";
import { marketingPageSlugs } from "@/constants/marketing-pages";
import type { MetadataRoute } from "next";

/** Les pages sur mesure vivent hors du gabarit `[slug]` mais restent indexables. */
const standalonePageSlugs = ["analytics", "blog", "community"] as const;

export default function sitemap(): MetadataRoute.Sitemap {
  const pageSlugs = [...standalonePageSlugs, ...marketingPageSlugs];
  const staticPages: MetadataRoute.Sitemap = pageSlugs.map((slug) => ({
    url: `${project.metadata.url}/${slug}`,
    lastModified: new Date(),
    changeFrequency: slug === "terms" ? "yearly" : "monthly",
    priority: slug === "help" ? 0.8 : 0.7,
  }));

  return [
    {
      url: project.metadata.url,
      lastModified: new Date(),
      changeFrequency: "weekly",
      priority: 1,
    },
    ...staticPages,
  ];
}
