import { project } from "@/constants/project";
import type { ArticleFrontmatter } from "./schema";

/**
 * Les données structurées d’un article.
 *
 * `Article` et `FAQPage` sont lus par Google et produisent des résultats
 * enrichis. `SpecialAnnouncement` est le type que schema.org définit pour une
 * annonce de service exceptionnelle — c’est sémantiquement le bon, mais il faut
 * être exact : le résultat enrichi que Google en tire est limité aux annonces
 * sanitaires. Il est donc émis parce qu’il est juste et lisible par d’autres
 * agents, pas en espérant un gain de classement.
 */
export function articleStructuredData({
  frontmatter,
  slug,
}: {
  readonly frontmatter: ArticleFrontmatter;
  readonly slug: string;
}): unknown[] {
  const url = `${project.metadata.url}/blog/${slug}`;
  const publisher = {
    "@type": "Organization",
    name: project.metadata.name,
    url: project.metadata.url,
  };

  return [
    {
      "@context": "https://schema.org",
      "@type": "Article",
      mainEntityOfPage: { "@type": "WebPage", "@id": url },
      headline: frontmatter.title,
      description: frontmatter.description,
      inLanguage: "fr-FR",
      datePublished: frontmatter.publishedAt,
      dateModified: frontmatter.updatedAt ?? frontmatter.publishedAt,
      author: publisher,
      publisher,
      // La vignette de l'article porte une URL versionnée que Next attribue au
      // fichier `opengraph-image` et que cette couche ne connaît pas. On cite
      // donc l'image du site : une URL juste vaut mieux qu'une URL précise
      // qui renvoie un 404.
      image: `${project.metadata.url}${project.metadata.ogImage}`,
    },
    {
      "@context": "https://schema.org",
      "@type": "FAQPage",
      mainEntity: frontmatter.faq.map((entry) => ({
        "@type": "Question",
        name: entry.question,
        acceptedAnswer: { "@type": "Answer", text: entry.answer },
      })),
    },
    {
      "@context": "https://schema.org",
      "@type": "SpecialAnnouncement",
      name: frontmatter.title,
      text: frontmatter.description,
      url,
      datePosted: frontmatter.publishedAt,
      ...(frontmatter.validUntil ? { expires: frontmatter.validUntil } : {}),
      // Un libellé plutôt qu’un identifiant Wikidata : mieux vaut une chaîne
      // exacte qu’une URI pointant vers la mauvaise entité.
      category: "Travaux et perturbations du réseau de transport",
      spatialCoverage: {
        "@type": "AdministrativeArea",
        name: "Île-de-France",
      },
    },
  ];
}
