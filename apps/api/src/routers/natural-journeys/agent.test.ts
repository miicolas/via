import { describe, expect, test } from 'bun:test';

import { runNaturalJourneyAgent } from './agent';
import { createHandleRegistry } from './handles';
import { createToolset } from './tools';
import { NOW, fakePlanner, fakeSearcher, finalTurn, scriptedTransport, toolCallTurn } from './__fixtures__/fixtures';

function buildAgentDeps() {
  const registry = createHandleRegistry();
  const searcher = fakeSearcher();
  const planner = fakePlanner();
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
  test('runs search → plan → finalize through the tool loop', async () => {
    const { registry, toolset, planner } = buildAgentDeps();
    const { transport, requests } = scriptedTransport([
      toolCallTurn('search_places', { query: 'Châtelet' }),
      toolCallTurn('plan_journeys', {
        origin: { kind: 'current_location' },
        destination: { handle: 'place_1' },
        datetimeRepresents: 'departure',
      }),
      finalTurn({ outcome: 'ready', planHandle: 'plan_1', unsupportedMessage: '', examples: [] }),
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
    // Usage accumulates across all three turns.
    expect(run.usage).toEqual({ input: 300, output: 60, total: 360 });

    // The transcript is resent every turn (stateless); the last request carries
    // the assistant tool calls and their outputs.
    const lastInput = requests.at(-1)!.input;
    expect(lastInput.some((item) => 'type' in item && item.type === 'function_call')).toBe(true);
    expect(lastInput.some((item) => 'type' in item && item.type === 'function_call_output')).toBe(
      true
    );
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
