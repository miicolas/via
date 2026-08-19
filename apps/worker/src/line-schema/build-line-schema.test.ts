import { describe, expect, test } from 'bun:test';

import { buildLineSchema, type LineVariant } from './build-line-schema';

const variant = (stopIds: string[], tripCount: number): LineVariant => ({ stopIds, tripCount });

const allStops = (schema: ReturnType<typeof buildLineSchema>) =>
  schema.sections.flatMap((section) => section.stopIds);

describe('buildLineSchema', () => {
  test('merges a skip-stop mission with the omnibus into the full station list', () => {
    // The RER A "DUCK" case: the semi-direct calls at a subset, the omnibus at
    // every station; the schema is their union in line order.
    const schema = buildLineSchema([
      variant(['A', 'C', 'E'], 120),
      variant(['A', 'B', 'C', 'D', 'E'], 80),
    ]);

    expect(schema.sections).toHaveLength(1);
    expect(schema.sections[0]).toMatchObject({ role: 'trunk', stopIds: ['A', 'B', 'C', 'D', 'E'] });
    expect(schema.originStopIds).toEqual(['A']);
    expect(schema.terminusStopIds).toEqual(['E']);
  });

  test('is deterministic across input order', () => {
    const variants = [
      variant(['A', 'B', 'C', 'F'], 50),
      variant(['A', 'C', 'F'], 50),
      variant(['A', 'B', 'D', 'F'], 50),
    ];
    const forward = buildLineSchema(variants);
    const shuffled = buildLineSchema([variants[2]!, variants[0]!, variants[1]!]);

    expect(shuffled).toEqual(forward);
  });

  test('keeps a real minority branch and drops a marginal terminus', () => {
    const schema = buildLineSchema([
      variant(['A', 'B', 'C'], 80),
      // A real branch: 15% of the direction ends at D.
      variant(['A', 'B', 'D'], 15),
      // A depot run: 2% ends at the yard.
      variant(['A', 'B', 'Yard'], 2),
    ]);

    expect(schema.terminusStopIds).toEqual(['C', 'D']);
    expect(allStops(schema)).not.toContain('Yard');
  });

  test('drops a stop only served by exceptional diversions', () => {
    const schema = buildLineSchema([
      variant(['A', 'B', 'C', 'D'], 400),
      // Two diverted trips call at a stop no regular mission serves.
      variant(['A', 'B', 'X', 'C', 'D'], 2),
    ]);

    expect(allStops(schema)).toEqual(['A', 'B', 'C', 'D']);
    expect(schema.warnings).toContain('dropped 1 diversion-only stops');
  });

  test('decomposes an RER-A-shaped direction into labeled sections', () => {
    // Three western origins — Cergy and Poissy join at a shared sub-trunk
    // before Saint-Germain merges — running to two eastern termini.
    const cergy = ['Cergy', 'Neuville', 'Sartrouville', 'Nanterre', 'Châtelet', 'Vincennes'];
    const poissy = ['Poissy', 'Achères', 'Sartrouville', 'Nanterre', 'Châtelet', 'Vincennes'];
    const stGermain = ['StGermain', 'Vésinet', 'Nanterre', 'Châtelet', 'Vincennes'];
    const schema = buildLineSchema([
      variant([...cergy, 'Val', 'MLV'], 90),
      variant([...poissy, 'Val', 'MLV'], 60),
      variant([...stGermain, 'Val', 'MLV'], 100),
      variant([...stGermain, 'Joinville', 'Boissy'], 80),
      variant([...cergy, 'Joinville', 'Boissy'], 40),
      variant([...poissy, 'Joinville', 'Boissy'], 30),
    ]);

    const allTermini = ['MLV', 'Boissy'];
    expect(schema.sections).toEqual([
      // Origin-side branches busiest first, the shared Cergy/Poissy sub-trunk
      // between its branches and the trunk.
      {
        role: 'branch',
        origins: ['StGermain'],
        termini: allTermini,
        stopIds: ['StGermain', 'Vésinet'],
      },
      { role: 'branch', origins: ['Cergy'], termini: allTermini, stopIds: ['Cergy', 'Neuville'] },
      { role: 'branch', origins: ['Poissy'], termini: allTermini, stopIds: ['Poissy', 'Achères'] },
      {
        role: 'branch',
        origins: ['Cergy', 'Poissy'],
        termini: allTermini,
        stopIds: ['Sartrouville'],
      },
      {
        role: 'trunk',
        origins: ['StGermain', 'Cergy', 'Poissy'],
        termini: allTermini,
        stopIds: ['Nanterre', 'Châtelet', 'Vincennes'],
      },
      {
        role: 'branch',
        origins: ['StGermain', 'Cergy', 'Poissy'],
        termini: ['MLV'],
        stopIds: ['Val', 'MLV'],
      },
      {
        role: 'branch',
        origins: ['StGermain', 'Cergy', 'Poissy'],
        termini: ['Boissy'],
        stopIds: ['Joinville', 'Boissy'],
      },
    ]);
    // Busiest first: StGermain carries 180 trips; MLV 250 against Boissy 150.
    expect(schema.originStopIds).toEqual(['StGermain', 'Cergy', 'Poissy']);
    expect(schema.terminusStopIds).toEqual(['MLV', 'Boissy']);
  });

  test('a metro direction is a single trunk', () => {
    const schema = buildLineSchema([
      variant(['Vincennes', 'Nation', 'Bastille', 'Défense'], 500),
      variant(['Vincennes', 'Nation', 'Bastille', 'Défense'], 120),
    ]);

    expect(schema.sections).toEqual([
      {
        role: 'trunk',
        origins: ['Vincennes'],
        termini: ['Défense'],
        stopIds: ['Vincennes', 'Nation', 'Bastille', 'Défense'],
      },
    ]);
  });

  test('breaks a cycle instead of throwing', () => {
    // Two missions disagree on the order of B and C (looping-line territory).
    const schema = buildLineSchema([
      variant(['A', 'B', 'C', 'D'], 100),
      variant(['A', 'C', 'B', 'D'], 90),
    ]);

    expect(allStops(schema).toSorted()).toEqual(['A', 'B', 'C', 'D']);
    expect(schema.warnings.some((warning) => warning.startsWith('cycle broken'))).toBe(true);
  });

  test('returns an empty schema for no usable variants', () => {
    expect(buildLineSchema([variant(['Lone'], 10)])).toEqual({
      sections: [],
      originStopIds: [],
      terminusStopIds: [],
      warnings: [],
    });
  });
});
