import type { RouteIntent } from '@via/contract';

import { env } from '../../env';
import { naturalJourneyEvaluationCorpus } from './evaluation-corpus';
import { createNaturalLanguageModel, NATURAL_JOURNEY_PROMPT_VERSION } from './model';
import { normalizePlaceName } from './place-resolver';

const EVALUATION_NOW = new Date('2026-08-14T07:12:00Z');
const REQUIRED_ACCURACY = 0.95;

const model = createNaturalLanguageModel({
  apiKey: env.OPENAI_API_KEY,
  model: env.OPENAI_MODEL,
  inputCostPerMillion: env.OPENAI_INPUT_COST_PER_MILLION,
  outputCostPerMillion: env.OPENAI_OUTPUT_COST_PER_MILLION,
});
if (!model) throw new Error('OPENAI_API_KEY est requise pour l’évaluation manuelle.');

let correct = 0;
let silentCriticalErrors = 0;
const failures: Array<{ id: string; fields: string[] }> = [];

for (const item of naturalJourneyEvaluationCorpus) {
  const { intent } = await model.interpret(item.phrase, EVALUATION_NOW);
  const fields = compare(intent, item.expected);
  if (fields.length === 0) correct += 1;
  else failures.push({ id: item.id, fields });
  if (fields.some((field) => field === 'origin' || field === 'destination' || field === 'datetimeRepresents')) {
    silentCriticalErrors += 1;
  }
}

const accuracy = correct / naturalJourneyEvaluationCorpus.length;
console.info('[natural-journeys:eval]', {
  promptVersion: NATURAL_JOURNEY_PROMPT_VERSION,
  total: naturalJourneyEvaluationCorpus.length,
  correct,
  accuracy,
  silentCriticalErrors,
  failures,
});
if (accuracy < REQUIRED_ACCURACY || silentCriticalErrors > 0) process.exitCode = 1;

function compare(
  actual: RouteIntent,
  expected: (typeof naturalJourneyEvaluationCorpus)[number]['expected']
) {
  const failures: string[] = [];
  if (actual.scope !== expected.scope) failures.push('scope');
  const origin = actual.origin.kind === 'current_location' ? 'current_location' : actual.origin.query;
  if (!sameText(origin, expected.origin)) failures.push('origin');
  if (!sameText(actual.destinationQuery, expected.destination)) failures.push('destination');
  if (actual.datetimeRepresents !== expected.datetimeRepresents) failures.push('datetimeRepresents');
  if (!sameModes(actual.requiredModes, expected.requiredModes)) failures.push('requiredModes');
  if (!sameModes(actual.excludedModes, expected.excludedModes)) failures.push('excludedModes');
  if (!sameModes(actual.preferredModes, expected.preferredModes)) failures.push('preferredModes');
  if (actual.scope === 'journey' && actual.requestedAt === null) failures.push('requestedAt');
  const expectedAt = expectedInstant(expected.temporal);
  if (
    expectedAt &&
    actual.requestedAt &&
    Math.abs(Date.parse(actual.requestedAt) - expectedAt.getTime()) > 60_000
  ) failures.push('requestedAt');
  return failures;
}

function expectedInstant(temporal: string) {
  const fixed: Record<string, string> = {
    now: '2026-08-14T09:12:00+02:00',
    'next-future-06:00': '2026-08-15T06:00:00+02:00',
    'next-future-08:00': '2026-08-15T08:00:00+02:00',
    'next-future-09:00': '2026-08-15T09:00:00+02:00',
    'today-10:00': '2026-08-14T10:00:00+02:00',
    'tomorrow-09:00': '2026-08-15T09:00:00+02:00',
    'relative-45m': '2026-08-14T09:57:00+02:00',
    'relative-60m': '2026-08-14T10:12:00+02:00',
    '2026-09-18T14:00': '2026-09-18T14:00:00+02:00',
    'next-tuesday-07:30': '2026-08-18T07:30:00+02:00',
  };
  return fixed[temporal] ? new Date(fixed[temporal]) : null;
}

function sameText(actual: string | null, expected: string | null) {
  if (actual === null || expected === null) return actual === expected;
  return (
    normalizePlaceName(actual).includes(normalizePlaceName(expected)) ||
    normalizePlaceName(expected).includes(normalizePlaceName(actual))
  );
}

function sameModes(actual: string[], expected: string[]) {
  return [...actual].sort().join(',') === [...expected].sort().join(',');
}
