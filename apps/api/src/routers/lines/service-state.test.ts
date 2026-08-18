import { expect, test } from 'bun:test';

import type { NormalizedDisruption } from './disruptions/parse';
import { lineServiceState } from './service-state';

const now = 1_000_000;
const hour = 3_600;

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

test('a quiet line is normal with no summary', () => {
  expect(lineServiceState('IDFM:C01371', [], now)).toEqual({
    condition: 'normal',
    activeCount: 0,
  });
});

test('the worst active severity wins the badge and brings its title', () => {
  const state = lineServiceState(
    'IDFM:C01371',
    [
      disruption({ id: 'd-info', severity: 'attention', title: 'Info trafic' }),
      disruption({ id: 'd-block', severity: 'suspended', title: 'Trafic interrompu' }),
      disruption({ id: 'd-slow', severity: 'disrupted', title: 'Trafic perturbé' }),
    ],
    now
  );

  expect(state.condition).toBe('suspended');
  expect(state.summary).toBe('Trafic interrompu');
  expect(state.activeCount).toBe(3);
});

test('another line’s disruptions do not leak in', () => {
  const state = lineServiceState(
    'IDFM:C01371',
    [disruption({ routeIds: ['IDFM:C01742'], severity: 'suspended' })],
    now
  );

  expect(state).toEqual({ condition: 'normal', activeCount: 0 });
});

test('a healthy line with planned works carries the earliest upcoming start', () => {
  const state = lineServiceState(
    'IDFM:C01371',
    [
      disruption({
        id: 'd-later',
        periods: [{ beginsAt: now + 5 * hour, endsAt: now + 8 * hour }],
        title: 'Fermeture tardive',
      }),
      disruption({
        id: 'd-tonight',
        periods: [{ beginsAt: now + 2 * hour, endsAt: now + 4 * hour }],
        title: 'Fermeture ce soir',
      }),
    ],
    now
  );

  expect(state.condition).toBe('normal');
  expect(state.upcoming).toEqual({ beginsAt: now + 2 * hour, title: 'Fermeture ce soir' });
});

test('an active disruption and planned works can coexist', () => {
  const state = lineServiceState(
    'IDFM:C01371',
    [
      disruption({ id: 'd-now', severity: 'disrupted', title: 'Trafic perturbé' }),
      disruption({
        id: 'd-weekend',
        periods: [{ beginsAt: now + 24 * hour, endsAt: now + 48 * hour }],
        title: 'Travaux le week-end',
      }),
    ],
    now
  );

  expect(state.condition).toBe('disrupted');
  expect(state.activeCount).toBe(1);
  expect(state.upcoming?.title).toBe('Travaux le week-end');
});
