/**
 * The cities that may be voted for, as an allowlist and nothing more.
 *
 * What a visitor sees — the name, the region, where the dot sits on the drawn
 * map — is presentation, and lives with the drawing in
 * `apps/marketing/src/constants/cities.ts`. That file is the source of truth for
 * the roster; this one exists so a hand-written POST cannot invent a city, or a
 * typo split one city's votes across two rows. Adding a city means adding its
 * slug here too, and the test below is what says so out loud.
 *
 * Île-de-France is deliberately absent: it is served, not wanted.
 */
export const VOTABLE_CITY_SLUGS = [
  'bordeaux',
  'grenoble',
  'lille',
  'lyon',
  'marseille',
  'montpellier',
  'nantes',
  'nice',
  'rennes',
  'strasbourg',
  'toulouse',
] as const;

export type VotableCitySlug = (typeof VOTABLE_CITY_SLUGS)[number];

const votable = new Set<string>(VOTABLE_CITY_SLUGS);

export function isVotableCity(slug: string): slug is VotableCitySlug {
  return votable.has(slug);
}
