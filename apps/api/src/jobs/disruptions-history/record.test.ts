import { expect, test } from 'bun:test';

import { disruptionContentHash, disruptionSpanDays, toDisruptionRecord } from './record';
import type { NormalizedDisruption } from '../../routers/lines/disruptions/parse';

const day = 86_400;
const start = 1_780_000_000;

function disruption(overrides: Partial<NormalizedDisruption> = {}): NormalizedDisruption {
  return {
    id: 'prim-1',
    severity: 'disrupted',
    title: 'Travaux ligne 13',
    routeIds: ['IDFM:C01377'],
    periods: [{ beginsAt: start, endsAt: start + day }],
    impactedSections: [],
    ...overrides,
  };
}

test('the hash ignores the feed republishing without changing anything', () => {
  const before = disruption({ updatedAt: start });
  const after = disruption({ updatedAt: start + day });

  expect(disruptionContentHash(after)).toBe(disruptionContentHash(before));
});

test('the hash moves when the dates move', () => {
  const rescheduled = disruption({ periods: [{ beginsAt: start + day, endsAt: start + 2 * day }] });

  expect(disruptionContentHash(rescheduled)).not.toBe(disruptionContentHash(disruption()));
});

test('the hash ignores the order lines and sections arrive in', () => {
  const oneWay = disruption({ routeIds: ['IDFM:B', 'IDFM:A'] });
  const theOther = disruption({ routeIds: ['IDFM:A', 'IDFM:B'] });

  expect(disruptionContentHash(oneWay)).toBe(disruptionContentHash(theOther));
});

test('the window spans the outermost bounds of every period', () => {
  const record = toDisruptionRecord(
    disruption({
      periods: [
        { beginsAt: start + 10 * day, endsAt: start + 11 * day },
        { beginsAt: start, endsAt: start + day },
      ],
    })
  );

  expect(record.beginsAt).toEqual(new Date(start * 1_000));
  expect(record.endsAt).toEqual(new Date((start + 11 * day) * 1_000));
  expect(disruptionSpanDays(record)).toBe(11);
});

test('a disruption with no usable period carries no window', () => {
  const record = toDisruptionRecord(disruption({ periods: [] }));

  expect(record.beginsAt).toBeNull();
  expect(record.endsAt).toBeNull();
  expect(disruptionSpanDays(record)).toBe(0);
});

test('absent optional fields become null rather than undefined', () => {
  const record = toDisruptionRecord(disruption({ title: undefined }));

  expect(record.title).toBeNull();
  expect(record.cause).toBeNull();
  expect(record.message).toBeNull();
  expect(record.upstreamUpdatedAt).toBeNull();
});
