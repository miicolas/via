import { launch } from "./launch";
import type { CallToAction } from "./types";

export const analyticsContent = {
  metadata: {
    title: "Les données du réseau",
    description:
      "Metyro lit les jeux de données ouverts d’Île-de-France Mobilités : profils horaires de validation et état des ascenseurs, traduits en une réponse utile avant chaque trajet.",
  },
  hero: {
    badge: "Données ouvertes Île-de-France Mobilités",
    headline: {
      line1: "Les chiffres du réseau,",
      line2: "traduits en",
      accent: "minutes",
    },
    description:
      "Metyro lit les jeux de données publics d’Île-de-France Mobilités et n’en garde que ce qui change votre prochain trajet.",
    action: launch,
    secondaryAction: {
      label: "Voir les sources",
      href: "#sources",
    } satisfies CallToAction,
  },
  blurHeadline:
    "Deux questions décident d’un trajet : à quelle heure votre station respire, et si l’ascenseur fonctionne quand vous arrivez. Les données publiques répondent aux deux, à condition de les lire jusqu’au bout.",
  peak: {
    eyebrow: "Profils horaires de validation",
    title: "Votre station a des heures creuses",
    description:
      "Chaque station d’Île-de-France publie la répartition de ses validations, heure par heure. Touchez une heure pour voir ce qu’elle change.",
    station: "Gare du Nord",
    dayType: "Jours ouvrés hors vacances scolaires",
    unit: "des validations du jour",
    peakLabel: "C’est la pointe du matin.",
    emptyLabel: "Presque aucune validation à cette heure.",
    footnote: "Part des validations quotidiennes · T4 2024",
    facts: [
      {
        value: "30,19 %",
        label: "des validations tiennent dans les trois heures du matin.",
      },
      {
        value: "19,70 %",
        label: "seulement dans les trois heures du soir.",
      },
      {
        value: "2,6×",
        label: "moins de monde à 10 h qu’à la pointe du matin.",
      },
    ],
  },
  elevators: {
    eyebrow: "État des ascenseurs",
    title: "98,9 %, c’est encore quatre jours sans ascenseur",
    description:
      "Le meilleur taux du trimestre laisse quatre jours par an où l’ascenseur ne fonctionne pas. Une moyenne ne dit ni lequel, ni quand. Metyro lit donc l’état de chaque ascenseur, mis à jour en continu.",
    live: {
      title: "La moyenne, puis la réalité",
      hint: "Exemple d’affichage · basculez entre les deux lectures",
      station: "Gare du Nord",
      modes: ["Ce trimestre", "En ce moment"],
      quarter: {
        value: "98,9 %",
        label: "de disponibilité sur le trimestre",
        detail: "Objectif contractuel du RER B : 99,5 %",
      },
      elevators: [
        {
          id: "voirie",
          path: "Voirie ↔ Salle des échanges",
          status: "available",
          detail: "Vérifié il y a 2 min",
        },
        {
          id: "quai-41",
          path: "Salle des échanges ↔ Quai 41",
          status: "notavailable",
          detail: "Panne d’ascenseur · depuis 7 h 12",
        },
        {
          id: "quai-43",
          path: "Salle des échanges ↔ Quai 43",
          status: "available",
          detail: "Vérifié il y a 2 min",
        },
      ],
      statusLabels: {
        available: "Disponible",
        notavailable: "En panne",
      },
    },
    gap: {
      title: "Chaque réseau face à son objectif",
      hint: "Écart au contrat, T4 2024",
      aboveLabel: "au-dessus",
      belowLabel: "sous l’objectif",
    },
  },
  sources: {
    eyebrow: "Sources",
    title: "Tout est vérifiable",
    description:
      "Chaque chiffre de cette page garde son périmètre, sa période et son lien d’origine.",
  },
  download: {
    title: "Le réseau lu pour vous, à chaque trajet.",
    description:
      "Metyro fait ce travail dans votre poche : l’heure creuse de votre station et l’ascenseur qui fonctionne, sans ouvrir un seul jeu de données.",
    action: launch,
  },
} as const;

export type AnalyticsContent = typeof analyticsContent;
