import type { BrandContent } from "./types";

const siteUrl =
  process.env.NEXT_PUBLIC_SITE_URL ??
  (process.env.VERCEL_PROJECT_PRODUCTION_URL
    ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
    : "http://localhost:3000");

export const project = {
  brand: {
    name: "Metyro",
    homeHref: "/",
    logo: {
      name: "Logo Metyro",
      src: "/icon.svg",
    },
  } satisfies BrandContent,
  metadata: {
    name: "Metyro",
    description:
      "Le métro parisien en temps réel, dans une interface claire et immédiate.",
    url: siteUrl,
    ogImage: "/og-image.png",
    creator: "Metyro",
    authors: [{ name: "Metyro", url: siteUrl }],
    keywords: [
      "Metyro",
      "métro Paris",
      "transport en commun",
      "horaires en temps réel",
      "itinéraires",
    ],
  },
  theme: {
    defaultTheme: "system",
    enableSystemTheme: true,
  },
  features: {
    smoothScroll: true,
    parallaxHero: true,
    blurInHeadline: true,
  },
} as const;
