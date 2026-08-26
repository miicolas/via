import { describe, expect, test } from 'bun:test';
import type { NaturalJourneyModelInterpretation } from '@via/contract';

import { fakeRedis } from '../departures/__fixtures__/fake-redis';
import {
  CONFIG,
  NOW,
  finalTurn,
  rawFinalTurn,
  scriptedTransport,
} from './__fixtures__/fixtures';
import { createNaturalJourneyService } from './service';

const MODEL_INTERPRETATION: Omit<
  NaturalJourneyModelInterpretation,
  'alternateTimeConstraint' | 'lineStatus'
> & { alternateTimeConstraint: null; lineStatus: null } = {
  scope: 'journey',
  origin: { kind: 'query', value: 'Auber', evidence: 'depuis Auber' },
  destination: { kind: 'saved', value: 'home', evidence: 'chez moi' },
  originWasExplicit: true,
  lastServiceOfDay: false,
  timeConstraint: {
    reference: 'implicit_today',
    year: 2000,
    yearWasExplicit: false,
    month: 1,
    day: 1,
    timePrecision: 'unspecified',
    hour: 0,
    minute: 0,
    relativeAmount: 0,
    relativeUnit: 'minute',
    meaning: 'departure',
    evidence: '',
  },
  alternateTimeConstraint: null,
  requiredModes: [],
  excludedModes: [],
  preferredModes: [],
  unsupportedConstraints: [],
  unexplainedText: '',
  lineStatus: null,
};

const INTERPRETATION: NaturalJourneyModelInterpretation = {
  ...MODEL_INTERPRETATION,
  alternateTimeConstraint: undefined,
  lineStatus: undefined,
};

describe('natural-journey server interpreter', () => {
  test('classifies a grounded line-disruption question without inventing its live answer', async () => {
    const lineStatusInterpretation = {
      ...MODEL_INTERPRETATION,
      scope: 'line_status',
      origin: null,
      destination: null,
      originWasExplicit: false,
      lineStatus: {
        kind: 'specific',
        code: '4',
        mode: 'metro',
        evidence: 'métro 4',
      },
      // Luna may fill schema-required numeric placeholders from `now`; they
      // carry no user evidence and are ignored for a current line-status query.
      timeConstraint: {
        ...MODEL_INTERPRETATION.timeConstraint,
        year: 2026,
        month: 8,
        day: 26,
        hour: 16,
      },
      unexplainedText: '',
    } as const;
    const { transport } = scriptedTransport([finalTurn(lineStatusInterpretation)]);
    const service = createNaturalJourneyService({
      redis: fakeRedis().client,
      transport,
      clock: { now: () => NOW },
      config: CONFIG,
    });

    const result = await service.submit(
      {
        query: 'Y a-t-il des perturbations sur le métro 4 ?',
        locale: 'fr-FR',
        requestedAt: '2026-08-26T16:00:00.000Z',
        hasCurrentLocation: false,
        anchors: {},
        savedPlaces: [],
      },
      { identity: 'person-line-status' },
    );

    expect(result).toEqual({
      outcome: 'interpreted',
      interpretation: {
        ...lineStatusInterpretation,
        origin: undefined,
        destination: undefined,
        alternateTimeConstraint: undefined,
      },
    });
  });

  test('rejects a line code that was not copied from the question', async () => {
    const invalid = {
      ...MODEL_INTERPRETATION,
      scope: 'line_status',
      origin: null,
      destination: null,
      originWasExplicit: false,
      lineStatus: {
        kind: 'specific',
        code: '14',
        mode: 'metro',
        evidence: 'métro 4',
      },
    };
    const { transport } = scriptedTransport([finalTurn(invalid)]);
    const service = createNaturalJourneyService({
      redis: fakeRedis().client,
      transport,
      clock: { now: () => NOW },
      config: CONFIG,
    });

    const result = await service.submit(
      {
        query: 'Le métro 4 fonctionne ?',
        locale: 'fr-FR',
        requestedAt: '2026-08-26T16:00:00.000Z',
        hasCurrentLocation: false,
        anchors: {},
        savedPlaces: [],
      },
      { identity: 'person-invented-line' },
    );

    expect(result.outcome).toBe('unavailable');
  });

  test('without a server key it fails closed and records no request content', async () => {
    const metrics: Array<{ category: string }> = [];
    const service = createNaturalJourneyService({
      redis: fakeRedis().client,
      transport: null,
      clock: { now: () => NOW },
      config: CONFIG,
      recordMetric: (metric) => metrics.push(metric),
    });

    const result = await service.submit(baseInput(), { identity: 'person-42' });

    expect(result.outcome).toBe('unavailable');
    expect(metrics.map((metric) => metric.category)).toEqual(['no-key']);
    expect(JSON.stringify(metrics)).not.toContain('Auber');
  });

  test('the rollout kill switch returns unavailable without contacting OpenAI', async () => {
    const { transport, callCount } = scriptedTransport([finalTurn(MODEL_INTERPRETATION)]);
    const service = createNaturalJourneyService({
      redis: fakeRedis().client,
      transport,
      clock: { now: () => NOW },
      config: { ...CONFIG, rolloutPercent: 0 },
    });

    const result = await service.submit(
      {
        query: 'from Auber to Nation',
        locale: 'en',
        requestedAt: '2026-08-26T16:00:00.000Z',
        hasCurrentLocation: false,
        anchors: {},
        savedPlaces: [],
      },
      { identity: 'person-42' },
    );

    expect(result.outcome).toBe('unavailable');
    expect(callCount()).toBe(0);
  });

  test('returns one typed interpretation without giving the model journey tools or personal data', async () => {
    const { transport, requests, callCount } = scriptedTransport([
      finalTurn(MODEL_INTERPRETATION),
    ]);
    const service = createNaturalJourneyService({
      redis: fakeRedis().client,
      transport,
      clock: { now: () => NOW },
      config: CONFIG,
    });

    const result = await service.submit(
      {
        query: 'rentrez chez moi depuis Auber',
        locale: 'fr-FR',
        requestedAt: '2026-08-26T16:00:00.000Z',
        hasCurrentLocation: false,
        anchors: {
          origin: { kind: 'query', value: 'Auber', evidence: 'depuis Auber' },
          destination: { kind: 'saved', value: 'home', evidence: 'chez moi' },
        },
        savedPlaces: [{ id: 'home', label: 'Maison', kind: 'home' }],
      },
      { identity: 'person-42' },
    );

    expect(result).toEqual({ outcome: 'interpreted', interpretation: INTERPRETATION });
    expect(callCount()).toBe(1);
    expect(requests[0]?.tools).toEqual([]);
    const serialized = JSON.stringify(requests[0]);
    expect(serialized).not.toContain('latitude');
    expect(serialized).not.toContain('longitude');
    expect(serialized).not.toContain('Paris');
    expect(serialized).not.toContain('previous_response_id');
  });

  test('uses the same locked contract for an English request', async () => {
    const english = {
      ...MODEL_INTERPRETATION,
      origin: { kind: 'query', value: 'Auber', evidence: 'from Auber' },
      destination: { kind: 'query', value: 'Nation', evidence: 'to Nation' },
    };
    const { transport, requests } = scriptedTransport([finalTurn(english)]);
    const service = createNaturalJourneyService({
      redis: fakeRedis().client,
      transport,
      clock: { now: () => NOW },
      config: CONFIG,
    });

    const result = await service.submit(
      {
        query: 'get me from Auber to Nation',
        locale: 'en',
        requestedAt: '2026-08-26T16:00:00.000Z',
        hasCurrentLocation: false,
        anchors: {
          origin: { kind: 'query', value: 'Auber', evidence: 'from Auber' },
          destination: { kind: 'query', value: 'Nation', evidence: 'to Nation' },
        },
        savedPlaces: [],
      },
      { identity: 'person-en' },
    );

    expect(result.outcome).toBe('interpreted');
    const inputItem = requests[0]?.input[1];
    const userMessage =
      inputItem && 'content' in inputItem ? inputItem.content : undefined;
    expect(typeof userMessage).toBe('string');
    expect(JSON.parse(userMessage ?? '{}').locale).toBe('en');
  });

  test('preserves an anchored conversational reference without treating it as a place query', async () => {
    const contextual = {
      ...MODEL_INTERPRETATION,
      origin: undefined,
      destination: {
        kind: 'context_reference' as const,
        value: 'uniquely_confirmed_place',
        evidence: 'there',
      },
      originWasExplicit: false,
    };
    const { transport } = scriptedTransport([finalTurn(contextual)]);
    const service = createNaturalJourneyService({
      redis: fakeRedis().client,
      transport,
      clock: { now: () => NOW },
      config: CONFIG,
    });

    const result = await service.submit(
      {
        query: 'go there',
        locale: 'en',
        requestedAt: '2026-08-26T16:00:00.000Z',
        hasCurrentLocation: true,
        anchors: {
          destination: {
            kind: 'context_reference',
            value: 'uniquely_confirmed_place',
            evidence: 'there',
          },
        },
        savedPlaces: [],
      },
      { identity: 'person-context' },
    );

    expect(result.outcome).toBe('interpreted');
  });

  test('rejects a conversational reference that was not anchored by the app', async () => {
    const contextual = {
      ...MODEL_INTERPRETATION,
      origin: undefined,
      destination: {
        kind: 'context_reference' as const,
        value: 'uniquely_confirmed_place',
        evidence: 'there',
      },
      originWasExplicit: false,
    };
    const { transport } = scriptedTransport([finalTurn(contextual)]);
    const service = createNaturalJourneyService({
      redis: fakeRedis().client,
      transport,
      clock: { now: () => NOW },
      config: CONFIG,
    });

    const result = await service.submit(
      {
        query: 'go there',
        locale: 'en',
        requestedAt: '2026-08-26T16:00:00.000Z',
        hasCurrentLocation: true,
        anchors: {},
        savedPlaces: [],
      },
      { identity: 'person-context-unanchored' },
    );

    expect(result.outcome).toBe('unavailable');
  });

  test('rejects evidence that is not copied from the user turn', async () => {
    const invalid = {
      ...MODEL_INTERPRETATION,
      origin: { kind: 'query', value: 'Auber', evidence: 'Nation' },
    };
    const { transport } = scriptedTransport([finalTurn(invalid)]);
    const service = createNaturalJourneyService({
      redis: fakeRedis().client,
      transport,
      clock: { now: () => NOW },
      config: CONFIG,
    });

    const result = await service.submit(baseInput(), { identity: 'person-42' });

    expect(result.outcome).toBe('unavailable');
  });

  test('rejects a place name augmented beyond its exact evidence', async () => {
    const invalid = {
      ...MODEL_INTERPRETATION,
      origin: { kind: 'query', value: 'Auber Paris', evidence: 'depuis Auber' },
    };
    const { transport } = scriptedTransport([finalTurn(invalid)]);
    const service = createNaturalJourneyService({
      redis: fakeRedis().client,
      transport,
      clock: { now: () => NOW },
      config: CONFIG,
    });

    const result = await service.submit(
      { ...baseInput(), anchors: {} },
      { identity: 'person-42' },
    );

    expect(result.outcome).toBe('unavailable');
  });

  test('rejects any model attempt to swap locked origin and destination', async () => {
    const swapped = {
      ...MODEL_INTERPRETATION,
      origin: { kind: 'saved', value: 'home', evidence: 'chez moi' },
      destination: { kind: 'query', value: 'Auber', evidence: 'depuis Auber' },
    };
    const { transport } = scriptedTransport([finalTurn(swapped)]);
    const service = createNaturalJourneyService({
      redis: fakeRedis().client,
      transport,
      clock: { now: () => NOW },
      config: CONFIG,
    });

    const result = await service.submit(baseInput(), { identity: 'person-42' });

    expect(result.outcome).toBe('unavailable');
  });

  test('invalid JSON fails closed', async () => {
    const { transport } = scriptedTransport([rawFinalTurn('{not-json')]);
    const service = createNaturalJourneyService({
      redis: fakeRedis().client,
      transport,
      clock: { now: () => NOW },
      config: CONFIG,
    });

    const result = await service.submit(baseInput(), { identity: 'person-42' });

    expect(result.outcome).toBe('unavailable');
  });

  test('the personal rate limit is applied before a second model call', async () => {
    const { transport, callCount } = scriptedTransport([
      finalTurn(MODEL_INTERPRETATION),
      finalTurn(MODEL_INTERPRETATION),
    ]);
    const service = createNaturalJourneyService({
      redis: fakeRedis().client,
      transport,
      clock: { now: () => NOW },
      config: { ...CONFIG, personalLimit: 1 },
    });

    const first = await service.submit(baseInput(), { identity: 'person-42' });
    const second = await service.submit(baseInput(), { identity: 'person-42' });

    expect(first.outcome).toBe('interpreted');
    expect(second.outcome).toBe('unavailable');
    expect(callCount()).toBe(1);
  });

  test('an already cancelled request never contacts OpenAI', async () => {
    const { transport, callCount } = scriptedTransport([finalTurn(MODEL_INTERPRETATION)]);
    const controller = new AbortController();
    controller.abort(new DOMException('cancelled', 'AbortError'));
    const service = createNaturalJourneyService({
      redis: fakeRedis().client,
      transport,
      clock: { now: () => NOW },
      config: CONFIG,
    });

    await expect(
      service.submit(baseInput(), { identity: 'person-42', signal: controller.signal }),
    ).rejects.toMatchObject({ name: 'AbortError' });
    expect(callCount()).toBe(0);
  });
});

function baseInput() {
  return {
    query: 'rentrez chez moi depuis Auber',
    locale: 'fr-FR' as const,
    requestedAt: '2026-08-26T16:00:00.000Z',
    hasCurrentLocation: false,
    anchors: {
      origin: { kind: 'query' as const, value: 'Auber', evidence: 'depuis Auber' },
      destination: { kind: 'saved' as const, value: 'home', evidence: 'chez moi' },
    },
    savedPlaces: [{ id: 'home', label: 'Maison', kind: 'home' as const }],
  };
}
