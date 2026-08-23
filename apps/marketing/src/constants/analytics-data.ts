export const gareDuNordHourlyProfile = [
  { hour: "00h", share: 0.52 },
  { hour: "01h", share: 0.1 },
  { hour: "02h", share: 0.01 },
  { hour: "03h", share: 0 },
  { hour: "04h", share: 0 },
  { hour: "05h", share: 0.59 },
  { hour: "06h", share: 2.39 },
  { hour: "07h", share: 8.03 },
  { hour: "08h", share: 12.84 },
  { hour: "09h", share: 9.32 },
  { hour: "10h", share: 5.01 },
  { hour: "11h", share: 5.59 },
  { hour: "12h", share: 5.16 },
  { hour: "13h", share: 4.49 },
  { hour: "14h", share: 5.04 },
  { hour: "15h", share: 4.38 },
  { hour: "16h", share: 5.38 },
  { hour: "17h", share: 6.72 },
  { hour: "18h", share: 6.93 },
  { hour: "19h", share: 6.05 },
  { hour: "20h", share: 4.06 },
  { hour: "21h", share: 3.32 },
  { hour: "22h", share: 2.29 },
  { hour: "23h", share: 1.75 },
] as const;

export const elevatorAvailability = [
  { network: "Métro classique", result: 98.3, target: 97.5 },
  { network: "Métro modernisé", result: 98.8, target: 98 },
  { network: "Métro automatique", result: 98.9, target: 98 },
  { network: "RER A", result: 98.4, target: 99 },
  { network: "RER B", result: 98.9, target: 99.5 },
] as const;

export const analyticsSources = {
  hourlyProfile: {
    label:
      "Validations sur le réseau ferré — profils horaires, 4e trimestre 2024",
    href: "https://prim.iledefrance-mobilites.fr/jeux-de-donnees/validations-reseau-ferre-profils-horaires-par-jour-type-4eme-trimestre",
    note: "Gare du Nord, jours ouvrés hors vacances scolaires, réseau 110. La valeur représente la part des validations quotidiennes de chaque tranche horaire.",
  },
  accessibility: {
    label: "Indicateurs de qualité de service SNCF et RATP",
    href: "https://prim.iledefrance-mobilites.fr/fr/jeux-de-donnees/indicateurs-qualite-service-sncf-ratp",
    note: "Disponibilité des ascenseurs RATP, 4e trimestre 2024. La cible correspond à l’objectif de référence contractuel publié dans le même jeu de données.",
  },
} as const;
