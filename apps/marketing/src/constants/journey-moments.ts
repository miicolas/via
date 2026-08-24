import { transitLines as metroLines } from "./transit";
import type { JourneyMomentContent, JourneyMomentVisuals } from "./types";

export const journeyMoments = [
  {
    label: "Recherche",
    title: "Décrivez simplement où vous allez",
    description:
      "Écrivez votre trajet comme vous le pensez. Metyro comprend le lieu, l’heure et vos contraintes, directement sur votre iPhone.",
    detail: "Traité sur cet iPhone avec Apple Intelligence",
    icon: "search",
    color: "#1872f7",
  },
  {
    label: "En direct",
    title: "Votre trajet avance avec vous",
    description:
      "Prochain arrêt, correspondance et heure d’arrivée restent visibles au bon moment, même sur l’écran verrouillé.",
    detail: "Live Activity pendant tout le trajet",
    icon: "journey",
    color: "#1872f7",
  },
  {
    label: "Perturbations",
    title: "Voyez ce qui change avant de partir",
    description:
      "Les perturbations importantes remontent sans bruit inutile pour vous aider à adapter votre trajet à temps.",
    detail: "Informations trafic en temps réel",
    icon: "disruption",
    color: "#1872f7",
  },
  {
    label: "Stations",
    title: "Retrouvez les prochains départs",
    description:
      "Repérez les stations autour de vous et consultez les prochains passages sans fouiller dans des menus.",
    detail: "Carte et départs à proximité",
    icon: "station",
    color: "#1872f7",
  },
] as const satisfies readonly JourneyMomentContent[];

export const journeyMomentVisuals = {
  search: {
    prompt: "Gare de Lyon demain avant 9 h",
    result: {
      line: metroLines.m14,
      destination: "Gare de Lyon",
      note: "Départ 8 h 41 · Arrivée 8 h 56",
    },
  },
  journey: {
    line: metroLines.m1,
    destination: "Château de Vincennes",
    nextStop: "Prochain arrêt · Bastille",
    minutes: 3,
    unit: "MIN",
    progress: 0.68,
  },
  disruption: {
    alert: {
      title: "Ligne 13 · Trafic perturbé",
      note: "Reprise estimée vers 18 h 30",
    },
    reroute: {
      line: metroLines.m14,
      title: "Alternative proposée",
      note: "Via Saint-Lazare · +4 min",
    },
  },
  station: {
    name: "Châtelet",
    distance: "à 240 m",
    unit: "MIN",
    rows: [
      { line: metroLines.m1, destination: "La Défense", minutes: 2 },
      {
        line: metroLines.m14,
        destination: "Saint-Denis Pleyel",
        minutes: 4,
      },
    ],
  },
} as const satisfies JourneyMomentVisuals;
