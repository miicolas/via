/**
 * The cities the coverage map offers, and the roster the API validates a vote
 * against — `VOTABLE_CITY_SLUGS` in `apps/api/src/public/city-demand/catalogue.ts`
 * lists the same twelve slugs, and adding a city here means adding it there too.
 *
 * They live here rather than coming down with the counts so the map draws its
 * dots whether or not the API answers: a marketing page must never look empty
 * because a request timed out. Coordinates are the city centres; the drawn map
 * turns them into positions in `@/lib/france-map`.
 *
 * Île-de-France is deliberately absent: it is served, and the illustration
 * already marks it. Rouen is absent for a duller reason — it falls under that
 * marker on the drawing, and a dot nobody can see is a vote nobody can cast.
 */
export interface VotableCity {
  readonly slug: string;
  readonly name: string;
  readonly region: string;
  readonly latitude: number;
  readonly longitude: number;
}

export const votableCities: readonly VotableCity[] = [
  {
    slug: "lyon",
    name: "Lyon",
    region: "Auvergne-Rhône-Alpes",
    latitude: 45.764,
    longitude: 4.8357,
  },
  {
    slug: "marseille",
    name: "Marseille",
    region: "Provence-Alpes-Côte d’Azur",
    latitude: 43.2965,
    longitude: 5.3698,
  },
  {
    slug: "toulouse",
    name: "Toulouse",
    region: "Occitanie",
    latitude: 43.6047,
    longitude: 1.4442,
  },
  {
    slug: "lille",
    name: "Lille",
    region: "Hauts-de-France",
    latitude: 50.6292,
    longitude: 3.0573,
  },
  {
    slug: "bordeaux",
    name: "Bordeaux",
    region: "Nouvelle-Aquitaine",
    latitude: 44.8378,
    longitude: -0.5792,
  },
  {
    slug: "nice",
    name: "Nice",
    region: "Provence-Alpes-Côte d’Azur",
    latitude: 43.7102,
    longitude: 7.262,
  },
  {
    slug: "nantes",
    name: "Nantes",
    region: "Pays de la Loire",
    latitude: 47.2184,
    longitude: -1.5536,
  },
  {
    slug: "strasbourg",
    name: "Strasbourg",
    region: "Grand Est",
    latitude: 48.5734,
    longitude: 7.7521,
  },
  {
    slug: "rennes",
    name: "Rennes",
    region: "Bretagne",
    latitude: 48.1173,
    longitude: -1.6778,
  },
  {
    slug: "montpellier",
    name: "Montpellier",
    region: "Occitanie",
    latitude: 43.6108,
    longitude: 3.8767,
  },
  {
    slug: "grenoble",
    name: "Grenoble",
    region: "Auvergne-Rhône-Alpes",
    latitude: 45.1885,
    longitude: 5.7245,
  },
];
