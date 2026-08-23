import { describe, expect, test } from 'bun:test';

import { VOTABLE_CITY_SLUGS, isVotableCity } from './catalogue';
import { rankCities } from './ranking';

describe('the votable roster', () => {
  test('holds no duplicate and no stray casing', () => {
    expect(new Set(VOTABLE_CITY_SLUGS).size).toBe(VOTABLE_CITY_SLUGS.length);
    for (const slug of VOTABLE_CITY_SLUGS) expect(slug).toMatch(/^[a-z][a-z-]*[a-z]$/);
  });

  test('refuses anything it does not list', () => {
    expect(isVotableCity('lyon')).toBe(true);
    expect(isVotableCity('Lyon')).toBe(false);
    expect(isVotableCity('paris')).toBe(false);
  });
});

describe('rankCities', () => {
  test('returns every city on the roster, most wanted first', () => {
    const board = rankCities(new Map([['bordeaux', 3], ['lyon', 12]]));

    expect(board.cities).toHaveLength(VOTABLE_CITY_SLUGS.length);
    expect(board.cities.slice(0, 2).map((city) => city.slug)).toEqual(['lyon', 'bordeaux']);
    expect(board.totalVotes).toBe(15);
  });

  test('gives equal cities the same rank and skips the ones they consumed', () => {
    const board = rankCities(new Map([['lyon', 9], ['nice', 4], ['rennes', 4], ['lille', 1]]));
    const rankOf = (slug: string) => board.cities.find((city) => city.slug === slug)?.rank;

    expect(rankOf('lyon')).toBe(1);
    expect(rankOf('nice')).toBe(2);
    expect(rankOf('rennes')).toBe(2);
    expect(rankOf('lille')).toBe(4);
  });

  test('leaves an unwanted city without a rank', () => {
    const board = rankCities(new Map([['lyon', 1]]));

    expect(board.cities.filter((city) => city.rank !== null)).toEqual([
      { slug: 'lyon', votes: 1, rank: 1 },
    ]);
  });

  test('counts nothing for a slug outside the roster', () => {
    const board = rankCities(new Map([['paris', 400]]));

    expect(board.totalVotes).toBe(0);
  });
});
