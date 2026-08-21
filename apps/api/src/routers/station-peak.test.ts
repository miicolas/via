import { expect, test } from 'bun:test';

import { PEAK_LEVEL_LABELS, peakLevelForRatio } from './station-peak';

test('uses relative station thresholds for the three profile levels', () => {
  expect(peakLevelForRatio(0.49)).toBe('off');
  expect(peakLevelForRatio(0.5)).toBe('moderate');
  expect(peakLevelForRatio(0.8)).toBe('peak');
  expect(PEAK_LEVEL_LABELS).toEqual({
    off: 'heure creuse',
    moderate: 'fréquentation soutenue',
    peak: 'heure la plus chargée',
  });
});
