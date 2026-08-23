import type { LinkItem, NavigationGroup } from "./types";

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
        {
          label: "Integrations",
          description: "Connecter vos outils et vos flux",
          href: "/integrations",
        },
        {
          label: "API",
          description: "Construire avec les données Metyro",
          href: "/api",
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
          label: "Community",
          description: "Participer à l’avenir de Metyro",
          href: "/community",
        },
        {
          label: "Security",
          description: "Découvrir notre approche de la confiance",
          href: "/security",
        },
        {
          label: "Help",
          description: "Trouver une réponse rapidement",
          href: "/help",
        },
      ],
    },
  ] satisfies readonly NavigationGroup[],
  // pricing: { label: "Pricing", href: "#pricing" } satisfies LinkItem,
  signIn: { label: "Aide", href: "/help" } satisfies LinkItem,
  primaryAction: {
    label: "Télécharger",
    href: "#download",
  } satisfies LinkItem,
  mobileLead: { label: "Accueil", href: "/" } satisfies LinkItem,
} as const;

export const footerNavigation = [
  {
    label: "Produit",
    items: [
      { label: "API", href: "/api" },
      { label: "Integrations", href: "/integrations" },
      { label: "Analytics", href: "/analytics" },
    ],
  },
  {
    label: "Company",
    items: [
      { label: "Help", href: "/help" },
      { label: "Terms", href: "/terms" },
      { label: "Security", href: "/security" },
    ],
  },
  {
    label: "Découvrir",
    items: [
      { label: "Blog", href: "/blog" },
      { label: "Community", href: "/community" },
    ],
  },
] as const;
