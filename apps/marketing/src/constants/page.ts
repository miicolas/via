import type { CallToAction, LogoAsset } from "./types";
import { screenshots } from "./screenshots";

const appStoreAction = {
  label: "Télécharger Metyro",
  href: "#",
} satisfies CallToAction;

export const pageContent = {
  metadata: {
    title: "Metyro — Le métro en temps réel",
  },
  hero: {
    badge: "Disponible maintenant",
    headline: {
      line1: "Vos trajets en direct",
      line2: "Voyagez en",
      accent: "confiance",
    },
    description:
      "Stations, itinéraires et perturbations en temps réel, dans une app claire et immédiate.",
    action: appStoreAction,
    preview: screenshots.stationsOverview,
  },
  blurHeadline:
    "Metyro simplifie chacun de vos trajets en réunissant itinéraires, prochains passages et perturbations en temps réel dans une seule app, enrichie par Apple Intelligence pour vous accompagner à chaque étape.",
  journeyMoments: {
    title: "La bonne information, au bon moment",
    autoplayInterval: 10000,
  },
  pricing: {
    eyebrow: "Pricing",
    title: "Simple, transparent pricing",
    description:
      "Choose the plan that works best for your team. All plans include a 14-day free trial.",
  },
  faq: {
    eyebrow: "Questions fréquentes",
    title: "Tout savoir sur Metyro",
    description:
      "Une question sur l’app ou sur vos trajets ? Nous sommes là pour vous répondre.",
    primaryAction: appStoreAction,
    secondaryAction: {
      label: "Contacter l’assistance",
      href: "#",
    } satisfies CallToAction,
  },
  footer: {
    headline: "Le métro, toujours avec vous.",
    action: appStoreAction,
    copyright: "All rights reserved.",
  },
} as const;

export const heroLogos = [
  { name: "Acme Corp", src: "/mock-logos/acmecorp.svg" },
  { name: "Altshift", src: "/mock-logos/altshift.svg" },
  { name: "Biosynthesis", src: "/mock-logos/biosynthesis.svg" },
  { name: "Boltshift", src: "/mock-logos/boltshift.svg" },
  { name: "Capsule", src: "/mock-logos/capsule.svg" },
  { name: "Catalog", src: "/mock-logos/catalog.svg" },
  { name: "Cloudwatch", src: "/mock-logos/cloudwatch.svg" },
  { name: "Commandr", src: "/mock-logos/commandr.svg" },
] as const satisfies readonly LogoAsset[];

export type PageContent = typeof pageContent;
