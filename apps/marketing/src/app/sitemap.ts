import { project } from "@/constants/project";
import { marketingPageSlugs } from "@/constants/marketing-pages";
import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const staticPages: MetadataRoute.Sitemap = marketingPageSlugs.map((slug) => ({
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
