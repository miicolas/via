import type { MarketingIconName } from "./marketing-pages";
import type { CallToAction } from "./types";

export interface JournalEntry {
  readonly id: string;
  readonly icon: MarketingIconName;
  readonly category: string;
  readonly readingTime: string;
  readonly title: string;
  readonly standfirst: string;
  /** La question de relance, réservée au sujet d’ouverture. */
  readonly question?: string;
}

export const blogContent = {
  metadata: {
    title: "Le journal Metyro",
    description:
      "Le sommaire du premier numéro : six sujets sur les minutes que l’on ressent, les signaux que l’on croit et les décisions qui transforment un déplacement en trajet maîtrisé.",
  },
  hero: {
    badge: "Le journal Metyro · Nº 01",
    headline: {
      line1: "La ville n’a pas d’horaires.",
      line2: "Elle a des",
      accent: "habitudes",
    },
    description:
      "Nous enquêtons sur les minutes que l’on ressent, les signaux que l’on croit et les décisions minuscules qui transforment un déplacement en trajet maîtrisé.",
    primaryAction: {
      label: "Voir le sommaire",
      href: "#sommaire",
    } satisfies CallToAction,
    secondaryAction: {
      label: "Proposer un sujet",
      href: "/community",
    } satisfies CallToAction,
  },
  blurHeadline:
    "Un tableau de départ affiche une minute. Il ne dit pas si elle paraîtra longue, si le quai sera plein, ni s’il existe un autre chemin. Le journal Metyro s’occupe de tout ce que l’affichage laisse de côté.",
  index: {
    eyebrow: "Nº 01 · en préparation",
    title: "Au sommaire du premier numéro",
    description:
      "Six sujets en cours d’écriture. Chacun part d’un moment de trajet précis, jamais d’un thème général. Rien n’est encore publié — ce sommaire dit ce qui arrive.",
    leadLabel: "Ouverture",
    statusLabel: "En écriture",
  },
  entries: [
    {
      id: "minute-vecue",
      icon: "route",
      category: "Produit",
      readingTime: "6 min",
      title: "Une minute annoncée n’est pas une minute vécue",
      standfirst:
        "Sur un quai sans information, soixante secondes s’étirent. Avec une estimation crédible et une alternative visible, elles redeviennent du temps que l’on peut décider.",
      question: "Pourquoi la même minute paraît deux fois plus longue ?",
    },
    {
      id: "trafic-perturbe",
      icon: "activity",
      category: "Design",
      readingTime: "8 min",
      title: "« Trafic perturbé » ne dit presque rien",
      standfirst:
        "Une mauvaise nouvelle devient utile seulement lorsqu’elle nomme la portion, la durée, l’impact et le prochain choix possible.",
    },
    {
      id: "travail-invisible",
      icon: "database",
      category: "Ingénierie",
      readingTime: "10 min",
      title: "Le travail invisible derrière « 3 min »",
      standfirst:
        "Sources contradictoires, fraîcheur, repli théorique : l’interface la plus simple repose souvent sur la décision technique la plus exigeante.",
    },
    {
      id: "republique",
      icon: "compass",
      category: "Ville",
      readingTime: "5 min",
      title: "République n’est pas un point. C’est un petit territoire.",
      standfirst:
        "Accès, couloirs, quais, correspondances et habitudes locales : une station possède sa propre géographie vécue.",
    },
    {
      id: "itineraire-possible",
      icon: "heart",
      category: "Accessibilité",
      readingTime: "7 min",
      title: "L’itinéraire le plus court n’est pas toujours possible",
      standfirst:
        "Concevoir pour l’accessibilité oblige à quitter la ligne droite et à regarder les équipements, les pentes et les interruptions réelles.",
    },
    {
      id: "confiance",
      icon: "shield",
      category: "Sécurité",
      readingTime: "4 min",
      title: "La confiance ne se maquette pas",
      standfirst:
        "Elle se construit dans les données que l’on refuse de collecter, les accès que l’on limite et les promesses que l’on peut vérifier.",
    },
  ] as const satisfies readonly JournalEntry[],
  closing: {
    title: "Le sujet qui vous manque, dites-le-nous.",
    description:
      "Un détail précis vaut mieux qu’un grand thème. Racontez le moment exact où l’information vous a manqué : c’est là que commence le prochain article.",
    action: {
      label: "Rejoindre la communauté",
      href: "/community",
    } satisfies CallToAction,
  },
} as const;

export type BlogContent = typeof blogContent;
