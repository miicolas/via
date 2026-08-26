import { expect, test } from 'bun:test';

import { toPublicLineDetail, toPublicLineStatuses } from './projection';
import type { LineDetailResponse, LineStatusesResponse } from '@via/contract';

const badge = {
  id: 'IDFM:C01377',
  shortName: '13',
  mode: 'metro' as const,
  color: '#6ec4e8',
  textColor: '#111111',
};

function statuses(): LineStatusesResponse {
  return {
    source: 'live',
    fetchedAt: '2026-08-26T10:00:00+02:00',
    lines: [
      {
        route: badge,
        condition: 'disrupted',
        summary: 'Travaux entre Porte de Clichy et Les Courtilles',
        activeCount: 2,
        upcoming: { beginsAt: '2026-09-24T04:30:00+02:00', title: 'Fermeture' },
      },
    ],
  };
}

function detail(): LineDetailResponse {
  return {
    route: badge,
    branches: [
      {
        id: 'pattern-1',
        directionId: 0,
        headsign: 'Châtillon - Montrouge',
        isCanonical: true,
        stops: [{ id: 'IDFM:1', name: 'Garibaldi' }],
      },
    ],
    directions: [
      {
        directionId: 0,
        label: 'Châtillon - Montrouge',
        sections: [
          {
            role: 'trunk',
            origins: ['IDFM:1'],
            termini: ['IDFM:2'],
            stops: [{ id: 'IDFM:1', name: 'Garibaldi', isInterchange: false }],
          },
        ],
      },
    ],
    source: 'live',
    fetchedAt: '2026-08-26T10:00:00+02:00',
    disruptions: [
      {
        id: 'prim-1',
        severity: 'disrupted',
        activity: 'active',
        cause: 'TRAVAUX',
        title: 'Fermeture de Porte de Saint-Ouen',
        message: 'Texte intégral du message IDFM, sur plusieurs paragraphes.',
        periods: [{ beginsAt: '2026-09-24T04:30:00+02:00', endsAt: '2026-09-28T01:30:00+02:00' }],
        impactedSections: [
          {
            fromStopId: 'IDFM:1',
            fromName: 'Porte de Saint-Ouen',
            toStopId: 'IDFM:2',
            toName: 'Porte de Saint-Ouen',
          },
        ],
      },
    ],
  };
}

test('a line status keeps its identity and its condition', () => {
  const [line] = toPublicLineStatuses(statuses()).lines;

  expect(line).toEqual({
    id: 'IDFM:C01377',
    mode: 'metro',
    shortName: '13',
    condition: 'disrupted',
    activeCount: 2,
    summary: 'Travaux entre Porte de Clichy et Les Courtilles',
    upcoming: { beginsAt: '2026-09-24T04:30:00+02:00', title: 'Fermeture' },
  });
});

/**
 * The point of ADR 0003's amendment: `/public` is a hand-written projection,
 * so a field added to the contract cannot become public by accident. These two
 * tests fail the day someone forwards a contract response wholesale.
 */
test('the line schema never crosses into the public payload', () => {
  const projected = toPublicLineDetail(detail()) as Record<string, unknown>;

  expect(projected['directions']).toBeUndefined();
  expect(projected['branches']).toBeUndefined();
  expect(projected['route']).toBeUndefined();
});

test('the feed’s own prose is dropped, and stop ids with it', () => {
  const [disruption] = toPublicLineDetail(detail()).disruptions;

  expect(disruption).toEqual({
    id: 'prim-1',
    severity: 'disrupted',
    activity: 'active',
    cause: 'TRAVAUX',
    title: 'Fermeture de Porte de Saint-Ouen',
    periods: [{ beginsAt: '2026-09-24T04:30:00+02:00', endsAt: '2026-09-28T01:30:00+02:00' }],
    impactedSections: [{ fromName: 'Porte de Saint-Ouen', toName: 'Porte de Saint-Ouen' }],
  });
});

test('an unavailable feed is reported as such rather than as a healthy line', () => {
  const projected = toPublicLineStatuses({ source: 'unavailable', lines: [] });

  expect(projected.source).toBe('unavailable');
  expect(projected.fetchedAt).toBeUndefined();
});
