import { project } from "@/constants/project";
import { marketingPageSlugs } from "@/constants/marketing-pages";
import { listArticleSummaries, listCoveredLines } from "@/lib/blog/loader";
import type { MetadataRoute } from "next";

/** Les pages sur mesure vivent hors du gabarit `[slug]` mais restent indexables. */
const standalonePageSlugs = ["analytics", "blog", "community"] as const;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const pageSlugs = [...standalonePageSlugs, ...marketingPageSlugs];
  const staticPages: MetadataRoute.Sitemap = pageSlugs.map((slug) => ({
    url: `${project.metadata.url}/${slug}`,
    lastModified: new Date(),
    changeFrequency: slug === "terms" ? "yearly" : "monthly",
    priority: slug === "help" ? 0.8 : 0.7,
  }));

  const [articles, lines] = await Promise.all([listArticleSummaries(), listCoveredLines()]);

  /*
   * Un article porte sa vraie date de mise à jour, pas celle du build : dire à
   * Google que tout le site a changé à chaque déploiement est le meilleur moyen
   * qu’il cesse d’écouter.
   */
  const articlePages: MetadataRoute.Sitemap = articles.map((article) => ({
    url: `${project.metadata.url}/blog/${article.slug}`,
    lastModified: new Date(
      `${article.frontmatter.updatedAt ?? article.frontmatter.publishedAt}T12:00:00Z`,
    ),
    // Un chantier terminé ne bouge plus ; un chantier en cours peut être révisé.
    changeFrequency: article.status === "ended" ? "yearly" : "weekly",
    priority: article.status === "ended" ? 0.4 : 0.8,
  }));

  /* Les hubs sont l’actif durable de la rubrique : ils ne périment jamais. */
  const linePages: MetadataRoute.Sitemap = lines.map((line) => ({
    url: `${project.metadata.url}/blog/ligne/${line}`,
    lastModified: new Date(),
    changeFrequency: "weekly",
    priority: 0.9,
  }));

  return [
    {
      url: project.metadata.url,
      lastModified: new Date(),
      changeFrequency: "weekly",
      priority: 1,
    },
    ...staticPages,
    ...linePages,
    ...articlePages,
  ];
}
