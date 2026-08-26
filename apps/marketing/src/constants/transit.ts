import type { TransitLine } from "./types";

/** Une ligne du référentiel, avec le mode qui décide de son libellé accessible. */
export interface TransitLineRef extends TransitLine {
  readonly mode: "metro" | "rer";
}

/** Couleurs officielles Île-de-France Mobilités, les mêmes que dans l’app. */
export const transitLines = {
  m1: { mode: "metro", shortName: "1", color: "#ffcd00", textColor: "#111111" },
  m2: { mode: "metro", shortName: "2", color: "#003ca6", textColor: "#ffffff" },
  m3: { mode: "metro", shortName: "3", color: "#837902", textColor: "#ffffff" },
  m4: { mode: "metro", shortName: "4", color: "#cf009e", textColor: "#ffffff" },
  m5: { mode: "metro", shortName: "5", color: "#ff7e2e", textColor: "#111111" },
  m6: { mode: "metro", shortName: "6", color: "#6eca97", textColor: "#111111" },
  m7: { mode: "metro", shortName: "7", color: "#fa9aba", textColor: "#111111" },
  m8: { mode: "metro", shortName: "8", color: "#e19bdf", textColor: "#111111" },
  m9: { mode: "metro", shortName: "9", color: "#b6bd00", textColor: "#111111" },
  m10: {
    mode: "metro",
    shortName: "10",
    color: "#c9910d",
    textColor: "#111111",
  },
  m11: {
    mode: "metro",
    shortName: "11",
    color: "#704b1c",
    textColor: "#ffffff",
  },
  m12: {
    mode: "metro",
    shortName: "12",
    color: "#007852",
    textColor: "#ffffff",
  },
  m13: {
    mode: "metro",
    shortName: "13",
    color: "#6ec4e8",
    textColor: "#111111",
  },
  m14: {
    mode: "metro",
    shortName: "14",
    color: "#62259d",
    textColor: "#ffffff",
  },
  /*
   * Les lignes du Grand Paris Express n’ont pas encore de rame en service (la
   * 18 ouvre le 30 novembre 2026, la 15 Sud à l’automne 2027), donc aucun GTFS
   * ne les porte et l’instantané du réseau les ignore. Leurs couleurs sont
   * celles de la charte du projet ; un article qui les mentionne déclare ses
   * gares dans son frontmatter.
   */
  m15: {
    mode: "metro",
    shortName: "15",
    color: "#b90845",
    textColor: "#ffffff",
  },
  m16: {
    mode: "metro",
    shortName: "16",
    color: "#f3a4ba",
    textColor: "#111111",
  },
  m17: {
    mode: "metro",
    shortName: "17",
    color: "#d5c900",
    textColor: "#111111",
  },
  m18: {
    mode: "metro",
    shortName: "18",
    color: "#00a88f",
    textColor: "#ffffff",
  },
  rerA: { mode: "rer", shortName: "A", color: "#e3051c", textColor: "#ffffff" },
  rerB: { mode: "rer", shortName: "B", color: "#5291ce", textColor: "#ffffff" },
  rerC: { mode: "rer", shortName: "C", color: "#ffcc30", textColor: "#111111" },
  rerD: { mode: "rer", shortName: "D", color: "#008b5a", textColor: "#ffffff" },
  rerE: { mode: "rer", shortName: "E", color: "#c04191", textColor: "#ffffff" },
} as const satisfies Record<string, TransitLineRef>;

const { m1, m3, m4, m5, m8, m9, m11, m12, m13, m14, rerA, rerB, rerD, rerE } =
  transitLines;

export const metroLineByNumber: Readonly<
  Record<string, TransitLineRef | undefined>
> = Object.fromEntries(
  Object.values(transitLines)
    .filter((line) => line.mode === "metro")
    .map((line) => [line.shortName, line]),
);

export const rerLineByLetter: Readonly<
  Record<string, TransitLineRef | undefined>
> = Object.fromEntries(
  Object.values(transitLines)
    .filter((line) => line.mode === "rer")
    .map((line) => [line.shortName, line]),
);

/** Les lignes qui desservent chaque station citée sur le site, pour accompagner son nom de ses logos comme dans l’app. */
export const stationLines: Readonly<Record<string, readonly TransitLineRef[]>> =
  {
    République: [m3, m5, m8, m9, m11],
    Châtelet: [m1, m4, transitLines.m7, m11, m14],
    "Gare du Nord": [m4, m5, rerB, rerD, rerE],
    "Gare de Lyon": [m1, m14, rerA, rerD],
    "Saint-Lazare": [m3, m12, m13, m14, rerE],
    Bastille: [m1, m5, m8],
    "La Défense": [m1, rerA],
  };
