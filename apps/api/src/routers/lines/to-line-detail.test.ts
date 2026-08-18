import { expect, test } from 'bun:test';

import type { NormalizedDisruption } from './disruptions/parse';
import type { LineBranchStopRow } from './queries';
import { toLineBranches, toLineDisruptions } from './to-line-detail';

const now = 1_000_000;
const hour = 3_600;

function stopRow(overrides: Partial<LineBranchStopRow>): LineBranchStopRow {
  return {
    patternId: 'p-canonical-0',
    directionId: 0,
    headsign: 'Château de Vincennes',
    isCanonical: true,
    tripCount: 400,
    stopId: 'IDFM:71264',
    stopName: 'La Défense',
    stopSequence: 1,
    ...overrides,
  };
}

test('rows group into branches in travel order', () => {
  const branches = toLineBranches([
    stopRow({ stopSequence: 1 }),
    stopRow({ stopId: 'IDFM:71135', stopName: 'Nation', stopSequence: 2 }),
    stopRow({
      patternId: 'p-branch-0',
      isCanonical: false,
      tripCount: 80,
      headsign: 'Boissy-St-Léger',
      stopId: 'IDFM:70648',
      stopName: 'Boissy-St-Léger',
      stopSequence: 1,
    }),
  ]);

  expect(branches).toEqual([
    {
      id: 'p-canonical-0',
      directionId: 0,
      headsign: 'Château de Vincennes',
      isCanonical: true,
      stops: [
        { id: 'IDFM:71264', name: 'La Défense' },
        { id: 'IDFM:71135', name: 'Nation' },
      ],
    },
    {
      id: 'p-branch-0',
      directionId: 0,
      headsign: 'Boissy-St-Léger',
      isCanonical: false,
      stops: [{ id: 'IDFM:70648', name: 'Boissy-St-Léger' }],
    },
  ]);
});

function disruption(overrides: Partial<NormalizedDisruption>): NormalizedDisruption {
  return {
    id: 'd-1',
    severity: 'disrupted',
    routeIds: ['IDFM:C01371'],
    periods: [{ beginsAt: now - hour, endsAt: now + hour }],
    impactedSections: [],
    ...overrides,
  };
}

test('active disruptions lead, worst severity first, then upcoming by start', () => {
  const entries = toLineDisruptions(
    'IDFM:C01371',
    [
      disruption({
        id: 'd-weekend',
        periods: [{ beginsAt: now + 24 * hour, endsAt: now + 48 * hour }],
      }),
      disruption({ id: 'd-info', severity: 'attention' }),
      disruption({
        id: 'd-tonight',
        periods: [{ beginsAt: now + 2 * hour, endsAt: now + 4 * hour }],
      }),
      disruption({ id: 'd-block', severity: 'suspended' }),
    ],
    now
  );

  expect(entries.map((entry) => [entry.id, entry.activity])).toEqual([
    ['d-block', 'active'],
    ['d-info', 'active'],
    ['d-tonight', 'upcoming'],
    ['d-weekend', 'upcoming'],
  ]);
});

test('sections of other lines are stripped, past disruptions dropped', () => {
  const entries = toLineDisruptions(
    'IDFM:C01371',
    [
      disruption({
        id: 'd-shared',
        routeIds: ['IDFM:C01371', 'IDFM:C01742'],
        impactedSections: [
          {
            routeId: 'IDFM:C01371',
            fromStopId: 'IDFM:71264',
            fromName: 'La Défense',
            toStopId: 'IDFM:71135',
            toName: 'Nation',
          },
          {
            routeId: 'IDFM:C01742',
            fromStopId: 'IDFM:70001',
            fromName: 'Ailleurs',
            toStopId: 'IDFM:70002',
            toName: 'Autre part',
          },
        ],
      }),
      disruption({
        id: 'd-past',
        periods: [{ beginsAt: now - 4 * hour, endsAt: now - 2 * hour }],
      }),
    ],
    now
  );

  expect(entries).toHaveLength(1);
  expect(entries[0]?.impactedSections).toEqual([
    {
      fromStopId: 'IDFM:71264',
      fromName: 'La Défense',
      toStopId: 'IDFM:71135',
      toName: 'Nation',
    },
  ]);
});

test('epochs come out as ISO instants', () => {
  const [entry] = toLineDisruptions(
    'IDFM:C01371',
    [disruption({ periods: [{ beginsAt: now - hour, endsAt: now + hour }], updatedAt: now })],
    now
  );

  expect(entry?.periods).toEqual([
    {
      beginsAt: new Date((now - hour) * 1_000).toISOString(),
      endsAt: new Date((now + hour) * 1_000).toISOString(),
    },
  ]);
  expect(entry?.updatedAt).toBe(new Date(now * 1_000).toISOString());
});
