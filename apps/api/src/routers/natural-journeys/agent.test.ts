import { describe, expect, test } from 'bun:test';

import type { JourneysResponse } from '@via/contract';

import { runNaturalJourneyAgent } from './agent';
import { createHandleRegistry } from './handles';
import { createToolset } from './tools';
import {
  NOW,
  fakePlanner,
  fakeSearcher,
  finalTurn,
  scriptedTransport,
  toolCallTurn,
  toolCallsTurn,
} from './__fixtures__/fixtures';

function buildAgentDeps(planResponse?: JourneysResponse) {
  const registry = createHandleRegistry();
  const searcher = fakeSearcher();
  const planner = fakePlanner(planResponse);
  const toolset = createToolset({
    registry,
    searchPlaces: searcher.searchPlaces,
    planner: planner.planner,
    currentLocation: { latitude: 48.85, longitude: 2.35 },
    identity: 'user-1',
    defaultRequestedAt: NOW,
    now: NOW,
  });
  return { registry, toolset, planner };
}

const NEVER = new AbortController().signal;

describe('natural-journey agent', () => {
  test('a successful plan finalizes the run without a closing model turn', async () => {
    const { registry, toolset, planner } = buildAgentDeps();
    const { transport, requests, callCount } = scriptedTransport([
      toolCallTurn('search_places', { query: 'Châtelet' }),
      toolCallTurn('plan_journeys', {
        origin: { kind: 'current_location' },
        destination: { handle: 'place_1' },
        datetimeRepresents: 'departure',
      }),
    ]);

    const run = await runNaturalJourneyAgent({
      transport,
      toolset,
      registry,
      model: 'gpt-5.6-luna',
      safetyIdentifier: 'hmac',
      userMessage: 'aller à Châtelet',
      timeoutMs: 8_000,
      signal: NEVER,
    });

    expect(run.result.kind).toBe('ready');
    expect(planner.calls).toHaveLength(1);
    expect(run.toolCalls).toEqual({ searchPlaces: 1, planJourneys: 1 });
    // The plan's success is the answer: exactly two turns, no closing message.
    expect(callCount()).toBe(2);
    expect(run.usage).toEqual({ input: 200, output: 40, total: 240 });

    // The transcript is resent every turn (stateless); the last request carries
    // the assistant tool calls and their outputs.
    const lastInput = requests.at(-1)!.input;
    expect(lastInput.some((item) => 'type' in item && item.type === 'function_call')).toBe(true);
    expect(lastInput.some((item) => 'type' in item && item.type === 'function_call_output')).toBe(
      true
    );
  });

  test('parallel searches in one turn come back in call order', async () => {
    const { registry, toolset } = buildAgentDeps();
    const { transport, requests } = scriptedTransport([
      toolCallsTurn([
        { name: 'search_places', args: { query: 'Châtelet' } },
        { name: 'search_places', args: { query: 'La Défense' } },
      ]),
      toolCallTurn('plan_journeys', {
        origin: { kind: 'handle', handle: 'place_1' },
        destination: { handle: 'place_2' },
        datetimeRepresents: 'departure',
      }),
    ]);

    const run = await runNaturalJourneyAgent({
      transport,
      toolset,
      registry,
      model: 'gpt-5.6-luna',
      safetyIdentifier: 'hmac',
      userMessage: 'de Châtelet à La Défense',
      timeoutMs: 8_000,
      signal: NEVER,
    });

    expect(run.result.kind).toBe('ready');
    expect(run.toolCalls).toEqual({ searchPlaces: 2, planJourneys: 1 });
    // Both search outputs land in the transcript, each answering its own call
    // id, in call order. (The captured input array is the live transcript, so
    // it also carries the later plan output — only the first two matter here.)
    const secondInput = requests.at(1)!.input;
    const outputs = secondInput.filter(
      (item): item is { type: 'function_call_output'; call_id: string; output: string } =>
        'type' in item && item.type === 'function_call_output'
    );
    expect(outputs.slice(0, 2).map((item) => item.call_id)).toEqual(['call_1', 'call_2']);
  });

  test('an empty plan leaves the conclusion to the model', async () => {
    const { registry, toolset } = buildAgentDeps({
      status: 'no-route',
      source: 'gtfs-theoretical',
      generatedAt: NOW.toISOString(),
      journeys: [],
    });
    const { transport, callCount } = scriptedTransport([
      toolCallTurn('search_places', { query: 'Châtelet' }),
      toolCallTurn('plan_journeys', {
        origin: { kind: 'current_location' },
        destination: { handle: 'place_1' },
        datetimeRepresents: 'departure',
      }),
      finalTurn({
        outcome: 'unsupported',
        planHandle: '',
        unsupportedMessage: 'Aucun trajet trouvé.',
        examples: ['de Gare du Nord à Châtelet'],
      }),
    ]);

    const run = await runNaturalJourneyAgent({
      transport,
      toolset,
      registry,
      model: 'gpt-5.6-luna',
      safetyIdentifier: 'hmac',
      userMessage: 'aller à Châtelet',
      timeoutMs: 8_000,
      signal: NEVER,
    });

    // No auto-finalization on a plan without journeys: the model still speaks.
    expect(callCount()).toBe(3);
    expect(run.result.kind).toBe('unsupported');
  });

  test('a deadline already passed returns a timeout without calling OpenAI', async () => {
    const { registry, toolset } = buildAgentDeps();
    const { transport, callCount } = scriptedTransport([]);
    let ticks = 0;
    // First read seeds the deadline; the loop's second read is already past it.
    const clock = () => (ticks++ === 0 ? 0 : 10_000);

    const run = await runNaturalJourneyAgent({
      transport,
      toolset,
      registry,
      model: 'gpt-5.6-luna',
      safetyIdentifier: 'hmac',
      userMessage: 'aller à Châtelet',
      timeoutMs: 8_000,
      signal: NEVER,
      clock,
    });

    expect(run.result).toEqual({ kind: 'error', category: 'timeout' });
    expect(callCount()).toBe(0);
  });

  test('overrunning the tool budget ends as tool-budget-exceeded', async () => {
    const { registry, toolset } = buildAgentDeps();
    const { transport } = scriptedTransport(
      Array.from({ length: 5 }, () => toolCallTurn('search_places', { query: 'x' }))
    );

    const run = await runNaturalJourneyAgent({
      transport,
      toolset,
      registry,
      model: 'gpt-5.6-luna',
      safetyIdentifier: 'hmac',
      userMessage: 'boucle',
      timeoutMs: 60_000,
      signal: NEVER,
    });

    expect(run.result).toEqual({ kind: 'error', category: 'tool-budget-exceeded' });
  });

  test('an already-aborted signal throws instead of returning', async () => {
    const { registry, toolset } = buildAgentDeps();
    const { transport } = scriptedTransport([]);
    const aborted = AbortSignal.abort(new DOMException('cancelled', 'AbortError'));

    await expect(
      runNaturalJourneyAgent({
        transport,
        toolset,
        registry,
        model: 'gpt-5.6-luna',
        safetyIdentifier: 'hmac',
        userMessage: 'aller à Châtelet',
        timeoutMs: 8_000,
        signal: aborted,
      })
    ).rejects.toBeInstanceOf(DOMException);
  });
});
