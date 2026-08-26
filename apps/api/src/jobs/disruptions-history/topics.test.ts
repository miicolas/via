import { expect, test } from 'bun:test';

import { toDisruptionRecord, type DisruptionRecord } from './record';
import { selectTopics, type KnownDisruption } from './topics';
import type { NormalizedDisruption } from '../../routers/lines/disruptions/parse';

const day = 86_400;
const now = new Date('2026-09-01T08:00:00.000Z');
const nowSeconds = Math.floor(now.getTime() / 1_000);

function record(overrides: Partial<NormalizedDisruption> = {}): DisruptionRecord {
  const disruption: NormalizedDisruption = {
    id: 'prim-1',
    severity: 'suspended',
    title: 'Fermeture',
    routeIds: ['IDFM:C01377'],
    periods: [{ beginsAt: nowSeconds + day, endsAt: nowSeconds + 5 * day }],
    impactedSections: [],
    ...overrides,
  };
  return toDisruptionRecord(disruption);
}

function known(entries: Record<string, string>): Map<string, KnownDisruption> {
  return new Map(
    Object.entries(entries).map(([id, contentHash]) => [id, { contentHash } satisfies KnownDisruption])
  );
}

test('an unseen closure is reported as appeared', () => {
  const topics = selectTopics([record()], known({}), now);

  expect(topics).toHaveLength(1);
  expect(topics[0]?.reasons).toEqual(['appeared']);
});

test('a closure seen yesterday and unchanged is not reported again', () => {
  const subject = record();

  expect(selectTopics([subject], known({ 'prim-1': subject.contentHash }), now)).toEqual([]);
});

test('a closure whose dates moved is reported as rescheduled', () => {
  const subject = record();
  const topics = selectTopics([subject], known({ 'prim-1': 'a-different-hash' }), now);

  expect(topics[0]?.reasons).toEqual(['rescheduled']);
});

test('a works programme stays on the list even when nothing changed', () => {
  const subject = record({ periods: [{ beginsAt: nowSeconds, endsAt: nowSeconds + 60 * day }] });
  const topics = selectTopics([subject], known({ 'prim-1': subject.contentHash }), now);

  expect(topics[0]?.reasons).toEqual(['long-running']);
  expect(topics[0]?.spanDays).toBe(60);
});

test('attention-level notices never become subjects', () => {
  const subject = record({ severity: 'attention' });

  expect(selectTopics([subject], known({}), now)).toEqual([]);
});

test('a closure shorter than two days is an incident, not a subject', () => {
  const subject = record({ periods: [{ beginsAt: nowSeconds, endsAt: nowSeconds + 3_600 }] });

  expect(selectTopics([subject], known({}), now)).toEqual([]);
});

test('a closure that is already over is not news', () => {
  const subject = record({
    periods: [{ beginsAt: nowSeconds - 30 * day, endsAt: nowSeconds - 10 * day }],
  });

  expect(selectTopics([subject], known({}), now)).toEqual([]);
});

test('suspended lines are ranked above disrupted ones, then by length', () => {
  const topics = selectTopics(
    [
      record({ id: 'short-suspension' }),
      record({
        id: 'long-disruption',
        severity: 'disrupted',
        periods: [{ beginsAt: nowSeconds, endsAt: nowSeconds + 90 * day }],
      }),
      record({
        id: 'long-suspension',
        periods: [{ beginsAt: nowSeconds, endsAt: nowSeconds + 40 * day }],
      }),
    ],
    known({}),
    now
  );

  expect(topics.map((topic) => topic.id)).toEqual([
    'long-suspension',
    'short-suspension',
    'long-disruption',
  ]);
});
