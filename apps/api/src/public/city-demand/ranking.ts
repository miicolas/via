import { VOTABLE_CITY_SLUGS, type VotableCitySlug } from './catalogue';

export type CityDemand = {
  readonly slug: VotableCitySlug;
  readonly votes: number;
  /**
   * Position in the ranking, `null` while the city has no vote at all. A city
   * nobody asked for has no rank to show — printing "12e" under an empty
   * counter would read as a result rather than as an invitation.
   */
  readonly rank: number | null;
};

export type CityDemandBoard = {
  readonly cities: readonly CityDemand[];
  readonly totalVotes: number;
};

/**
 * The roster joined to its counts, ordered the way the leaderboard reads: most
 * wanted first, alphabetical between equals so the order is stable from one
 * render to the next. Ties share a rank — two cities on thirty votes are both
 * second and the next one is fourth, because a visitor comparing two dots reads
 * "ex æquo", not an arbitrary winner.
 */
export function rankCities(counts: ReadonlyMap<string, number>): CityDemandBoard {
  const scored = VOTABLE_CITY_SLUGS.map((slug) => ({
    slug,
    votes: counts.get(slug) ?? 0,
  })).sort((a, b) => b.votes - a.votes || a.slug.localeCompare(b.slug, 'fr'));

  let rank = 0;
  let previousVotes = Number.NaN;

  const cities = scored.map((city, index) => {
    if (city.votes !== previousVotes) {
      rank = index + 1;
      previousVotes = city.votes;
    }
    return { ...city, rank: city.votes === 0 ? null : rank };
  });

  return {
    cities,
    totalVotes: cities.reduce((total, city) => total + city.votes, 0),
  };
}
