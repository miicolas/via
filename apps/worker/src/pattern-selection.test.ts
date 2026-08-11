import { describe, expect, test } from 'bun:test';

import { MIN_BRANCH_SHARE, selectPatterns, type PatternCandidate } from './pattern-selection';

const ROUTE = 'IDFM:C01371';

function candidate(overrides: Partial<PatternCandidate> & { shapeId: string }): PatternCandidate {
  return {
    routeId: ROUTE,
    directionId: 0,
    headsign: 'Château de Vincennes',
    representativeTripId: `trip-${overrides.shapeId}`,
    tripCount: 100,
    ...overrides,
  };
}

const shapeIds = (result: { patterns: PatternCandidate[] }) =>
  result.patterns.map((pattern) => pattern.shapeId).toSorted();

describe('selectPatterns', () => {
  test('keeps the busiest variant of each headsign', () => {
    const result = selectPatterns(
      [
        candidate({ shapeId: 'busy', tripCount: 300 }),
        candidate({ shapeId: 'quiet', tripCount: 200 }),
      ],
      ROUTE
    );

    // Same headsign, same direction: only the busiest track survives.
    expect(shapeIds(result)).toEqual(['busy']);
  });

  test('keeps each direction independently', () => {
    const result = selectPatterns(
      [
        candidate({ shapeId: 'eastbound', directionId: 0, tripCount: 300 }),
        candidate({ shapeId: 'westbound', directionId: 1, tripCount: 290 }),
      ],
      ROUTE
    );

    expect(shapeIds(result)).toEqual(['eastbound', 'westbound']);
  });

  /**
   * The rule that shapes the map: a terminus served by a handful of night trips
   * is not a branch a rider would recognise.
   */
  test(`drops a branch running under ${MIN_BRANCH_SHARE * 100}% of the busiest headsign`, () => {
    const result = selectPatterns(
      [
        candidate({ shapeId: 'trunk', headsign: 'Château de Vincennes', tripCount: 1000 }),
        candidate({ shapeId: 'real-branch', headsign: 'Nation', tripCount: 150 }),
        candidate({ shapeId: 'noise', headsign: 'Dépôt', tripCount: 99 }),
      ],
      ROUTE
    );

    expect(shapeIds(result)).toEqual(['real-branch', 'trunk']);
  });

  test('keeps a branch sitting exactly on the threshold', () => {
    const result = selectPatterns(
      [
        candidate({ shapeId: 'trunk', headsign: 'A', tripCount: 1000 }),
        candidate({ shapeId: 'edge', headsign: 'B', tripCount: 100 }),
      ],
      ROUTE
    );

    expect(shapeIds(result)).toEqual(['edge', 'trunk']);
  });

  /**
   * Two headsigns can run over the same track. The shape is a pattern primary
   * key, so it must be claimed once — and by its busiest claimant, otherwise the
   * canonical choice below would be decided by row order.
   */
  test('claims a shared shape once, at its highest trip count', () => {
    const result = selectPatterns(
      [
        candidate({ shapeId: 'shared', headsign: 'Nation', tripCount: 400 }),
        candidate({ shapeId: 'shared', headsign: 'Bastille', tripCount: 700 }),
      ],
      ROUTE
    );

    expect(result.patterns).toHaveLength(1);
    expect(result.patterns[0]!.tripCount).toBe(700);
  });

  test('names the busiest survivor canonical, across directions', () => {
    const result = selectPatterns(
      [
        candidate({ shapeId: 'eastbound', directionId: 0, tripCount: 300 }),
        candidate({ shapeId: 'westbound', directionId: 1, tripCount: 310 }),
      ],
      ROUTE
    );

    expect(result.canonicalShapeId).toBe('westbound');
  });

  test('names the line when a route has no usable trip', () => {
    expect(() => selectPatterns([], ROUTE)).toThrow(ROUTE);
  });
});
