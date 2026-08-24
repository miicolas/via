import { transitLines } from "./transit";

export const departurePreview = {
  eyebrow: "Détail en temps réel",
  title: "Le prochain métro, lisible en un regard.",
  description:
    "Les minutes défilent en direct, et un retard ou une avance apparaît dès que le réseau le signale.",
  unit: "MIN",
  accessibilityLabel: "Départs en temps réel",
  onTimeLabel: "à l’heure",
  rows: [
    {
      id: "vincennes",
      line: transitLines.m1,
      destination: "Château de Vincennes",
      initialFavorite: true,
      frames: [
        { minutes: 3, status: "live", scheduled: "18 h 29", deltaMinutes: 0 },
        { minutes: 2, status: "live", scheduled: "18 h 29", deltaMinutes: 0 },
        {
          minutes: 5,
          status: "delayed",
          scheduled: "18 h 29",
          deltaMinutes: 3,
        },
        {
          minutes: 4,
          status: "delayed",
          scheduled: "18 h 29",
          deltaMinutes: 3,
        },
      ],
    },
    {
      id: "defense",
      line: transitLines.m1,
      destination: "La Défense",
      initialFavorite: false,
      frames: [
        { minutes: 6, status: "live", scheduled: "18 h 33", deltaMinutes: 0 },
        { minutes: 4, status: "early", scheduled: "18 h 33", deltaMinutes: 2 },
        { minutes: 3, status: "early", scheduled: "18 h 33", deltaMinutes: 2 },
      ],
    },
  ],
} as const;

export type DeparturePreview = typeof departurePreview;
export type DepartureFrame = DeparturePreview["rows"][number]["frames"][number];
export type DepartureFrameStatus = DepartureFrame["status"];
