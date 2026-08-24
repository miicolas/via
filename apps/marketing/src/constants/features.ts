import { transitLines } from "./transit";

export const featureContent = {
  onboarding: {
    title: "Tout le réseau, d’un coup d’œil",
    description:
      "Repérez les lignes, vos stations et les prochains passages sans quitter la carte.",
  },
  dashboard: {
    title: "Des départs vraiment en direct",
    description:
      "Les minutes défilent, et un retard ou une avance s’affiche aussitôt.",
  },
  intelligence: {
    badge: "Apple Intelligence",
    title: "Décrivez votre trajet",
    prompts: [
      {
        label: "Au Louvre à 9 h",
        text: "Au Louvre demain à 9 h",
        result: {
          line: transitLines.m1,
          destination: "Louvre — Rivoli",
          note: "Départ 8 h 41 · 12 min",
        },
      },
      {
        label: "Dernier train",
        text: "Dernier train pour chez moi",
        result: {
          line: transitLines.m14,
          destination: "Maison · Olympiades",
          note: "Dernier départ 0 h 47",
        },
      },
      {
        label: "Gare de Lyon",
        text: "Gare de Lyon avant 18 h",
        result: {
          line: transitLines.m14,
          destination: "Gare de Lyon",
          note: "Départ 17 h 38 · 9 min",
        },
      },
    ],
  },
  companion: {
    title: "Sur votre écran verrouillé",
    screen: {
      date: "dimanche 23 août",
      time: "21:47",
    },
    activity: {
      line: transitLines.m1,
      destination: "La Défense",
      unit: "MIN",
      phases: [
        { minutes: 3, stop: "2 arrêts", progress: 0.55 },
        { minutes: 2, stop: "1 arrêt", progress: 0.75 },
        { minutes: 1, stop: "Descendez ici", progress: 0.92 },
      ],
    },
  },
  highlights: {
    eyebrow: "Pensée pour vos trajets",
    title: "Chaque détail compte",
    description: "Affluence, accessibilité, horaires : essayez, tout répond.",
    crowding: {
      title: "Affluence signalée en direct",
      hint: "Touchez une ligne pour signaler",
      rows: [
        {
          line: transitLines.m1,
          station: "Châtelet",
          initialLevel: 0,
        },
        {
          line: transitLines.m14,
          station: "Bercy",
          initialLevel: 2,
        },
      ],
      levels: [
        { label: "Peu fréquenté", color: "#20bd57" },
        { label: "Affluence modérée", color: "#ff9f0a" },
        { label: "Très fréquenté", color: "#ff453a" },
      ],
    },
    accessibility: {
      title: "Accessibilité vérifiée",
      hint: "Filtrez les itinéraires accessibles",
      toggleLabel: "Itinéraires accessibles",
      status: "Ascenseur en service",
      detail: "Sortie 3 · accès de plain-pied",
    },
    schedule: {
      title: "Partez à votre heure",
      hint: "Faites glisser l’heure",
      options: ["Partir après", "Arriver avant"],
      times: ["08:30", "08:45", "09:00", "09:15", "09:30"],
    },
    favorites: {
      title: "Vos adresses, dans votre ordre",
      hint: "Glissez pour réorganiser, touchez + pour ajouter",
      chips: [
        { id: "home", label: "Maison", icon: "house" },
        { id: "work", label: "Travail", icon: "briefcase" },
      ],
      extras: [
        { id: "gym", label: "Sport", icon: "dumbbell" },
        { id: "school", label: "Fac", icon: "graduation" },
      ],
    },
  },
} as const;

export type FeaturesContent = typeof featureContent;
