import { expect, test } from 'bun:test';

import { completeStationPeakRows, parseStationPeakRows } from './import-station-peaks';

test('keeps the three supported day categories and discards school-day and ND rows', () => {
  const rows = parseStationPeakRows([
    { id_zdc: 12, cat_jour: 'JOHV', trnc_horr_60: '18H-19H', pourcentage_validations: 12.5 },
    { id_zdc: 12, cat_jour: 'SAHV', trnc_horr_60: '9H-10H', pourcentage_validations: '4,5' },
    { id_zdc: 12, cat_jour: 'DIJFP', trnc_horr_60: '10H-11H', pourcentage_validations: 3 },
    { id_zdc: 12, cat_jour: 'JOVS', trnc_horr_60: '18H-19H', pourcentage_validations: 99 },
    { id_zdc: 12, cat_jour: 'JOHV', trnc_horr_60: 'ND', pourcentage_validations: 99 },
  ]);

  expect(rows).toEqual([
    { stopId: 'IDFM:12', dayType: 'weekday', hour: 18, share: 12.5 },
    { stopId: 'IDFM:12', dayType: 'saturday', hour: 9, share: 4.5 },
    { stopId: 'IDFM:12', dayType: 'sunday', hour: 10, share: 3 },
  ]);
});

test('fills absent hours with zero and calculates a relative station peak', () => {
  const rows = completeStationPeakRows(
    [
      { stopId: 'IDFM:12', dayType: 'weekday', hour: 8, share: 10 },
      { stopId: 'IDFM:12', dayType: 'weekday', hour: 9, share: 5 },
    ],
    ['IDFM:12'],
    new Date('2026-02-20T00:00:00Z'),
    new Date('2026-08-21T00:00:00Z')
  );

  expect(rows).toHaveLength(72);
  expect(rows.find((row) => row.dayType === 'weekday' && row.hour === 8)).toMatchObject({
    share: 10,
    peakRatio: 1,
  });
  expect(rows.find((row) => row.dayType === 'weekday' && row.hour === 9)).toMatchObject({
    share: 5,
    peakRatio: 0.5,
  });
  expect(rows.find((row) => row.dayType === 'sunday' && row.hour === 3)).toMatchObject({
    share: 0,
    peakRatio: 0,
  });
});
