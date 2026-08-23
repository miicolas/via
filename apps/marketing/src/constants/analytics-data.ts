/**
 * Every value on /analytics comes from an Île-de-France Mobilités open dataset,
 * kept with its own scope and period. Nothing here is illustrative.
 */

export interface HourlyShare {
  readonly hour: number;
  readonly share: number;
}

/**
 * Part des validations quotidiennes par tranche horaire à Gare du Nord,
 * jours ouvrés hors vacances scolaires, T4 2024. Le total fait 99,97 %
 * (arrondis de la source).
 */
export const gareDuNordHourlyProfile = [
  { hour: 0, share: 0.52 },
  { hour: 1, share: 0.1 },
  { hour: 2, share: 0.01 },
  { hour: 3, share: 0 },
  { hour: 4, share: 0 },
  { hour: 5, share: 0.59 },
  { hour: 6, share: 2.39 },
  { hour: 7, share: 8.03 },
  { hour: 8, share: 12.84 },
  { hour: 9, share: 9.32 },
  { hour: 10, share: 5.01 },
  { hour: 11, share: 5.59 },
  { hour: 12, share: 5.16 },
  { hour: 13, share: 4.49 },
  { hour: 14, share: 5.04 },
  { hour: 15, share: 4.38 },
  { hour: 16, share: 5.38 },
  { hour: 17, share: 6.72 },
  { hour: 18, share: 6.93 },
  { hour: 19, share: 6.05 },
  { hour: 20, share: 4.06 },
  { hour: 21, share: 3.32 },
  { hour: 22, share: 2.29 },
  { hour: 23, share: 1.75 },
] as const satisfies readonly HourlyShare[];

export const peakHour = 8;
export const quietComparisonHour = 10;

export interface ElevatorAvailability {
  readonly network: string;
  readonly shortName: string;
  /** Disponibilité observée sur le trimestre, en %. */
  readonly result: number;
  /** Objectif de référence contractuel publié dans le même jeu de données. */
  readonly target: number;
}

/** Disponibilité des ascenseurs RATP au T4 2024, réseau par réseau. */
export const elevatorAvailability = [
  {
    network: "Métro classique",
    shortName: "Métro classique",
    result: 98.3,
    target: 97.5,
  },
  {
    network: "Métro modernisé",
    shortName: "Métro modernisé",
    result: 98.8,
    target: 98,
  },
  {
    network: "Métro automatique",
    shortName: "Métro automatique",
    result: 98.9,
    target: 98,
  },
  { network: "RER A", shortName: "RER A", result: 98.4, target: 99 },
  { network: "RER B", shortName: "RER B", result: 98.9, target: 99.5 },
] as const satisfies readonly ElevatorAvailability[];

/** Le meilleur résultat du trimestre, celui qui sert d’argument rassurant. */
export const bestElevatorResult = 98.9;

/** Jours d’indisponibilité sur une année, à ce taux. Arrondi au jour. */
export function unavailableDaysPerYear(availability: number): number {
  return Math.round(((100 - availability) / 100) * 365);
}

export interface DataSource {
  readonly title: string;
  readonly publisher: string;
  readonly scope: string;
  readonly period: string;
  readonly href: string;
}

export const analyticsSources = [
  {
    title: "Validations sur le réseau ferré — profils horaires par jour type",
    publisher: "Île-de-France Mobilités",
    scope:
      "Gare du Nord, jours ouvrés hors vacances scolaires. Chaque valeur est la part des validations du jour dans cette tranche horaire.",
    period: "4ᵉ trimestre 2024",
    href: "https://prim.iledefrance-mobilites.fr/jeux-de-donnees/validations-reseau-ferre-profils-horaires-par-jour-type-4eme-trimestre",
  },
  {
    title: "État des ascenseurs",
    publisher: "Île-de-France Mobilités",
    scope:
      "Un enregistrement par ascenseur : disponible, en panne ou fermé pour maintenance, avec la date du dernier changement d’état.",
    period: "Mis à jour en continu",
    href: "https://data.iledefrance-mobilites.fr/explore/dataset/etat-des-ascenseurs/information/",
  },
  {
    title: "Indicateurs de qualité de service SNCF et RATP",
    publisher: "Île-de-France Mobilités",
    scope:
      "Disponibilité trimestrielle des ascenseurs par réseau, comparée à l’objectif contractuel publié dans le même jeu de données.",
    period: "4ᵉ trimestre 2024",
    href: "https://prim.iledefrance-mobilites.fr/fr/jeux-de-donnees/indicateurs-qualite-service-sncf-ratp",
  },
] as const satisfies readonly DataSource[];
