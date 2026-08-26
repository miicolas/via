import { project } from "@/constants/project";
import type { Metadata } from "next";

const metadata = project.metadata;

export const baseMetadata: Metadata = {
  metadataBase: new URL(metadata.url),
  title: {
    default: metadata.name,
    template: `%s | ${metadata.name}`,
  },
  description: metadata.description,
  keywords: [...metadata.keywords],
  authors: [...metadata.authors],
  creator: metadata.creator,
  publisher: metadata.name,
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    locale: "en_US",
    url: metadata.url,
    title: metadata.name,
    description: metadata.description,
    siteName: metadata.name,
    images: [
      { url: metadata.ogImage, width: 1200, height: 630, alt: metadata.name },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: metadata.name,
    description: metadata.description,
    images: [metadata.ogImage],
    creator: metadata.creator,
  },
  icons: {
    icon: "/icon.svg",
    shortcut: "/icon.svg",
    apple: "/apple-icon.svg",
  },
  manifest: "/site.webmanifest",
};

export function createPageMetadata({
  title,
  description = metadata.description,
  path = "/",
}: {
  title: string;
  description?: string;
  path?: string;
}): Metadata {
  return {
    title,
    description,
    alternates: { canonical: path },
    openGraph: {
      title,
      description,
      url: `${metadata.url}${path}`,
      images: [{ url: metadata.ogImage, width: 1200, height: 630, alt: title }],
    },
    twitter: {
      title,
      description,
      images: [metadata.ogImage],
    },
  };
}

/**
 * Les métadonnées d’un article daté.
 *
 * Diffère de `createPageMetadata` sur trois points qui comptent tous pour un
 * contenu périssable : `openGraph.type` vaut `article`, les dates de
 * publication et de mise à jour sont déclarées, et l’image partagée est celle
 * que la route `opengraph-image` dessine pour cet article — pas la vignette
 * générique du site, qui ne dirait rien de quelle ligne est coupée.
 */
export function createArticleMetadata({
  title,
  description,
  path,
  publishedTime,
  modifiedTime,
}: {
  title: string;
  description: string;
  path: string;
  publishedTime: string;
  modifiedTime?: string;
}): Metadata {
  return {
    title,
    description,
    alternates: { canonical: path },
    openGraph: {
      type: "article",
      locale: "fr_FR",
      title,
      description,
      url: `${metadata.url}${path}`,
      publishedTime,
      ...(modifiedTime === undefined ? {} : { modifiedTime }),
      // Pas d'`images` ici : le fichier `opengraph-image.tsx` du segment la
      // fournit, avec l'URL versionnée que Next lui donne. L'écrire à la main
      // reviendrait à pointer vers une adresse qui n'existe pas.
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
    },
  };
}
