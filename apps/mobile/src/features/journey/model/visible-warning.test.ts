import { expect, test } from 'bun:test';
import type { Journey } from '@via/contract';

import { visibleJourneyWarning } from './visible-warning';

const baseJourney = {
  status: 'normal',
  warnings: [],
} as unknown as Journey;

test('scheduled journeys expose no warning copy', () => {
  expect(
    visibleJourneyWarning({
      ...baseJourney,
      status: 'theoretical',
      warnings: ['source notice'],
    })
  ).toBeUndefined();
});

test('operational warnings remain visible on other journeys', () => {
  expect(visibleJourneyWarning({ ...baseJourney, warnings: ['Trafic interrompu'] })).toBe(
    'Trafic interrompu'
  );
});
