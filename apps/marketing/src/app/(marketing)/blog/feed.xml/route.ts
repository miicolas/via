import { project } from "@/constants/project";
import { listArticleSummaries } from "@/lib/blog/loader";
import { statusLabels } from "@/lib/blog/status";

/**
 * Le flux RSS de la rubrique « Travaux & trafic ».
 *
 * Régénéré à la même cadence que les articles : son contenu vient de fichiers
 * du dépôt, il ne change qu’au déploiement.
 */
export const revalidate = 1800;

/**
 * `&`, `<` et `>` suffisent dans du contenu ; les apostrophes et guillemets
 * n’ont besoin d’être échappés que dans un attribut, et il n’y en a aucun ici.
 */
function escapeXml(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

export async function GET(): Promise<Response> {
  const site = project.metadata.url;
  const articles = await listArticleSummaries();

  const items = articles
    .map((article) => {
      const url = `${site}/blog/${article.slug}`;
      const date = new Date(`${article.frontmatter.publishedAt}T08:00:00+02:00`);

      return `    <item>
      <title>${escapeXml(article.frontmatter.title)}</title>
      <link>${url}</link>
      <guid isPermaLink="true">${url}</guid>
      <pubDate>${date.toUTCString()}</pubDate>
      <category>${escapeXml(statusLabels[article.status])}</category>
      <description>${escapeXml(article.frontmatter.description)}</description>
    </item>`;
    })
    .join("\n");

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>${escapeXml(project.metadata.name)} — Travaux &amp; trafic</title>
    <link>${site}/blog</link>
    <atom:link href="${site}/blog/feed.xml" rel="self" type="application/rss+xml" />
    <description>Les travaux, fermetures et ouvertures du réseau francilien, expliqués ligne par ligne.</description>
    <language>fr-FR</language>
${items}
  </channel>
</rss>
`;

  return new Response(xml, {
    headers: {
      "content-type": "application/rss+xml; charset=utf-8",
      "cache-control": "public, max-age=1800, s-maxage=1800",
    },
  });
}
