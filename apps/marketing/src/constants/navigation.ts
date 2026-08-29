import type { LinkItem, NavigationGroup } from "./types";
import { launchNavigation } from "./launch";

export const navigation = {
  groups: [
    {
      label: "Produit",
      items: [
        {
          label: "Analytics",
          description: "Comprendre les mouvements du réseau",
          href: "/analytics",
        },
      ],
    },
    {
      label: "Ressources",
      items: [
        {
          label: "Blog",
          description: "Analyses, produit et mobilité",
          href: "/blog",
        },
        {
          label: "Communauté",
          description: "Participer à l’avenir de Metyro",
          href: "/community",
        },
        {
          label: "Sécurité",
          description: "Découvrir notre approche de la confiance",
          href: "/security",
        },
        {
          label: "Aide",
          description: "Trouver une réponse rapidement",
          href: "/help",
        },
      ],
    },
  ] satisfies readonly NavigationGroup[],
  // pricing: { label: "Pricing", href: "#pricing" } satisfies LinkItem,
  signIn: { label: "Aide", href: "/help" } satisfies LinkItem,
  primaryAction: launchNavigation,
  mobileLead: { label: "Accueil", href: "/" } satisfies LinkItem,
} as const;

export const footerNavigation = [
  {
    label: "Produit",
    items: [
      { label: "Analytics", href: "/analytics" },
    ],
  },
  {
    label: "Entreprise",
    items: [
      { label: "Aide", href: "/help" },
      { label: "Conditions", href: "/terms" },
      { label: "Sécurité", href: "/security" },
    ],
  },
  {
    label: "Découvrir",
    items: [
      { label: "Blog", href: "/blog" },
      { label: "Communauté", href: "/community" },
    ],
  },
] as const;
