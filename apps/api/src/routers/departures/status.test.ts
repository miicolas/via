import { expect, test } from 'bun:test';

import { normalizePrimDepartureStatus, qualifyDepartureStatus } from './status';

test('the signed delay stays on time below the 120 second threshold', () => {
  expect(qualifyDepartureStatus({ scheduledAt: 1_000, expectedAt: 1_119 })).toEqual({
    status: 'on_time',
    delaySeconds: 119,
  });
  expect(qualifyDepartureStatus({ scheduledAt: 1_000, expectedAt: 881 })).toEqual({
    status: 'on_time',
    delaySeconds: -119,
  });
});

test('the threshold includes exactly 120 seconds in both directions', () => {
  expect(qualifyDepartureStatus({ scheduledAt: 1_000, expectedAt: 1_120 })).toEqual({
    status: 'delayed',
    delaySeconds: 120,
  });
  expect(qualifyDepartureStatus({ scheduledAt: 1_000, expectedAt: 880 })).toEqual({
    status: 'early',
    delaySeconds: -120,
  });
});

test('missing Aimed time keeps a realtime item neutral', () => {
  expect(qualifyDepartureStatus({ expectedAt: 1_120 })).toEqual({ status: 'no_report' });
});

test('does not treat PRIM default onTime as proof without an Aimed baseline', () => {
  expect(
    qualifyDepartureStatus({ expectedAt: 1_120, providerStatus: 'on_time' })
  ).toEqual({ status: 'no_report' });
  expect(
    qualifyDepartureStatus({ expectedAt: 1_120, providerStatus: 'delayed' })
  ).toEqual({ status: 'delayed' });
  expect(
    qualifyDepartureStatus({ expectedAt: 1_120, providerStatus: 'early' })
  ).toEqual({ status: 'early' });
});

test('operational provider statuses win over timing deltas', () => {
  expect(
    qualifyDepartureStatus({
      scheduledAt: 1_000,
      expectedAt: 1_300,
      providerStatus: 'cancelled',
    })
  ).toEqual({ status: 'cancelled' });
});

test('provider status spelling is normalized to snake_case', () => {
  expect(normalizePrimDepartureStatus('onTime')).toBe('on_time');
  expect(normalizePrimDepartureStatus('not expected')).toBe('no_report');
  expect(normalizePrimDepartureStatus('DEPARTED')).toBe('departed');
});
