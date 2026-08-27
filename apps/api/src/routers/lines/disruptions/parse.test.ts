import { expect, test } from 'bun:test';

import { parseDisruptionsBulk } from './parse';

/** Epoch seconds of a Paris wall-clock instant, DST included. */
function parisEpoch(iso: string): number {
  return Math.floor(Date.parse(iso) / 1_000);
}

const bulkBody = {
  disruptions: [
    {
      id: 'd-blocking',
      cause: 'perturbation',
      severity: 'bloquante',
      title: 'Trafic interrompu',
      message: '<p>Trafic interrompu entre <b>La D&eacute;fense</b> et Nation.</p><p>Reprise estim&#233;e &agrave; 18h.</p>',
      lastUpdate: '20260818T101500',
      applicationPeriods: [{ begin: '20260818T060000', end: '20260818T180000' }],
      impactedSections: [
        {
          lineId: 'line:IDFM:C01371',
          from: { id: 'stop_area:IDFM:71264', name: 'La Défense' },
          to: { id: 'stop_area:IDFM:71135', name: 'Nation' },
        },
      ],
    },
    {
      id: 'd-works',
      cause: 'travaux',
      severity: 'information',
      title: 'Fermeture en soirée',
      message: 'Fermeture &agrave; partir de 22h.',
      applicationPeriods: [{ begin: '20260820T220000', end: '20260821T010000' }],
    },
    {
      id: 'd-orphan',
      severity: 'perturbee',
      title: 'Sans ligne rattachée',
      applicationPeriods: [{ begin: '20260818T060000', end: '20260818T180000' }],
    },
  ],
  lines: [
    {
      id: 'line:IDFM:C01742',
      shortName: 'A',
      mode: 'RapidTransit',
      impactedObjects: [
        { type: 'line', id: 'line:IDFM:C01742', name: 'RER A', disruptionIds: ['d-works'] },
        {
          type: 'stop_point',
          id: 'stop_point:IDFM:monomodalStopPlace:473875',
          name: 'Nation',
          disruptionIds: ['d-works'],
        },
      ],
    },
  ],
};

test('normalizes a blocking disruption with its cut section', () => {
  const [disruption] = parseDisruptionsBulk(bulkBody);

  expect(disruption).toEqual({
    id: 'd-blocking',
    severity: 'suspended',
    cause: 'perturbation',
    title: 'Trafic interrompu',
    message: 'Trafic interrompu entre La Défense et Nation.\nReprise estimée à 18h.',
    routeIds: ['IDFM:C01371'],
    periods: [
      {
        beginsAt: parisEpoch('2026-08-18T06:00:00+02:00'),
        endsAt: parisEpoch('2026-08-18T18:00:00+02:00'),
      },
    ],
    impactedSections: [
      {
        routeId: 'IDFM:C01371',
        fromStopId: 'IDFM:71264',
        fromName: 'La Défense',
        toStopId: 'IDFM:71135',
        toName: 'Nation',
      },
    ],
    updatedAt: parisEpoch('2026-08-18T10:15:00+02:00'),
  });
});

test('joins lines to disruptions through the inverse index', () => {
  const disruptions = parseDisruptionsBulk(bulkBody);
  const works = disruptions.find((entry) => entry.id === 'd-works');

  expect(works?.routeIds).toEqual(['IDFM:C01742']);
  expect(works?.impactedStops).toEqual([{
    routeId: 'IDFM:C01742',
    stopId: 'IDFM:monomodalStopPlace:473875',
    stopName: 'Nation',
  }]);
  expect(works?.severity).toBe('attention');
});

test('drops a disruption no line claims', () => {
  const ids = parseDisruptionsBulk(bulkBody).map((entry) => entry.id);
  expect(ids).toEqual(['d-blocking', 'd-works']);
});

test('an unknown severity degrades to attention instead of dropping', () => {
  const [disruption] = parseDisruptionsBulk({
    disruptions: [
      {
        id: 'd-new-severity',
        severity: 'nouvelle-valeur',
        impactedSections: [
          {
            lineId: 'line:IDFM:C01371',
            from: { id: 'stop_area:IDFM:71264', name: 'La Défense' },
            to: { id: 'stop_area:IDFM:71135', name: 'Nation' },
          },
        ],
      },
    ],
  });

  expect(disruption?.severity).toBe('attention');
});

test('malformed periods and sections drop silently', () => {
  const [disruption] = parseDisruptionsBulk({
    disruptions: [
      {
        id: 'd-partial',
        severity: 'perturbee',
        applicationPeriods: [
          { begin: 'pas-une-date', end: '20260818T180000' },
          { begin: '20260818T180000', end: '20260818T060000' },
          { begin: '20260818T060000', end: '20260818T180000' },
        ],
        impactedSections: [
          { lineId: 'line:IDFM:C01371', from: { id: 'stop_area:IDFM:71264' } },
          {
            lineId: 'line:IDFM:C01371',
            from: { id: 'stop_area:IDFM:71264', name: 'La Défense' },
            to: { id: 'stop_area:IDFM:71135', name: 'Nation' },
          },
        ],
      },
    ],
  });

  expect(disruption?.periods).toHaveLength(1);
  expect(disruption?.impactedSections).toHaveLength(1);
});

test('a winter datetime lands on the +01:00 offset', () => {
  const [disruption] = parseDisruptionsBulk({
    disruptions: [
      {
        id: 'd-winter',
        severity: 'perturbee',
        applicationPeriods: [{ begin: '20261215T060000', end: '20261215T180000' }],
        impactedSections: [
          {
            lineId: 'line:IDFM:C01371',
            from: { id: 'stop_area:IDFM:71264', name: 'La Défense' },
            to: { id: 'stop_area:IDFM:71135', name: 'Nation' },
          },
        ],
      },
    ],
  });

  expect(disruption?.periods).toEqual([
    {
      beginsAt: parisEpoch('2026-12-15T06:00:00+01:00'),
      endsAt: parisEpoch('2026-12-15T18:00:00+01:00'),
    },
  ]);
});

test('an empty or alien body parses to nothing', () => {
  expect(parseDisruptionsBulk(null)).toEqual([]);
  expect(parseDisruptionsBulk({})).toEqual([]);
  expect(parseDisruptionsBulk({ disruptions: 'oops', lines: 12 })).toEqual([]);
});
