import { expect, test } from 'bun:test';

import { naturalJourneyEvaluationCorpus } from './evaluation-corpus';

test('versions at least 150 annotated French journey requests', () => {
  expect(naturalJourneyEvaluationCorpus.length).toBeGreaterThanOrEqual(150);
  expect(new Set(naturalJourneyEvaluationCorpus.map(({ id }) => id)).size).toBe(
    naturalJourneyEvaluationCorpus.length
  );
  expect(naturalJourneyEvaluationCorpus.every(({ phrase }) => phrase.trim().length > 0)).toBe(true);
});

test('treats a destination followed by a bare time as an arrival', () => {
  const example = naturalJourneyEvaluationCorpus.find(
    ({ phrase }) => phrase === 'Gare du Nord à 11 h'
  );

  expect(example?.expected).toMatchObject({
    destination: 'Gare du Nord',
    datetimeRepresents: 'arrival',
    temporal: 'next-future-11:00',
  });
});
