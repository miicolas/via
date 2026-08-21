import { describe, expect, test } from 'bun:test';

import type { SearchResult } from '@via/contract';

import { createHandleRegistry } from './handles';
import { MAX_PLANS, MAX_SEARCHES, type ToolsetConfig, createToolset } from './tools';
import { ADDRESS, NOW, STATION, fakePlanner, fakeSearcher } from './__fixtures__/fixtures';

function buildToolset(overrides: Partial<ToolsetConfig> = {}) {
  const registry = overrides.registry ?? createHandleRegistry();
  const searcher = fakeSearcher(overrides.searchPlaces ? undefined : [STATION, ADDRESS]);
  const planner = fakePlanner();
  const toolset = createToolset({
    registry,
    searchPlaces: overrides.searchPlaces ?? searcher.searchPlaces,
    planner: overrides.planner ?? planner.planner,
    currentLocation: overrides.currentLocation ?? { latitude: 48.85, longitude: 2.35 },
    identity: 'user-1',
    defaultRequestedAt: NOW,
    now: NOW,
    ...overrides,
  });
  return { toolset, registry, searcher, planner };
}

async function call(
  toolset: ReturnType<typeof buildToolset>['toolset'],
  name: string,
  args: unknown
) {
  return JSON.parse(await toolset.runTool(name, JSON.stringify(args)));
}

describe('search_places tool', () => {
  test('returns opaque handles and never leaks coordinates', async () => {
    const { toolset } = buildToolset();
    const raw = await toolset.runTool('search_places', JSON.stringify({ query: 'Châtelet' }));

    expect(raw).not.toContain('48.8583');
    expect(raw).not.toContain('coordinate');
    const parsed = JSON.parse(raw);
    expect(parsed.ok).toBe(true);
    expect(parsed.places).toEqual([
      { handle: 'place_1', kind: 'station', label: 'Châtelet', context: undefined },
      { handle: 'place_2', kind: 'address', label: '12 Rue de Rivoli', context: '75004 Paris' },
    ]);
  });

  test('caps candidates at five handles', async () => {
    const many: SearchResult[] = Array.from({ length: 9 }, (_, i) => ({
      ...STATION,
      id: `stop_${i}`,
      name: `Station ${i}`,
    }));
    const { toolset } = buildToolset({ searchPlaces: async () => ({ results: many, banAvailable: true }) });
    const parsed = await call(toolset, 'search_places', { query: 'x' });

    expect(parsed.places).toHaveLength(5);
  });

  test('refuses more than the search budget', async () => {
    const { toolset } = buildToolset();
    for (let i = 0; i < MAX_SEARCHES; i += 1) {
      const ok = await call(toolset, 'search_places', { query: `q${i}` });
      expect(ok.ok).toBe(true);
    }
    const overrun = await call(toolset, 'search_places', { query: 'too many' });

    expect(overrun.ok).toBe(false);
    expect(overrun.error).toContain('Budget de recherche');
    expect(toolset.guardrailTriggered()).toBe(true);
  });

  test('resolves the Home favorite when present', async () => {
    const home: SearchResult = { ...ADDRESS, id: 'home', name: 'Chez moi' };
    const { toolset, registry } = buildToolset({ favorites: { home } });
    const parsed = await call(toolset, 'search_places', { query: 'maison' });

    expect(parsed.places).toHaveLength(1);
    expect(registry.resolvePlace(parsed.places[0].handle)).toEqual(home);
  });
});

describe('plan_journeys tool', () => {
  test('builds a Via journey input from handles and returns a plan handle', async () => {
    const { toolset, registry, planner } = buildToolset();
    await call(toolset, 'search_places', { query: 'Châtelet' });

    const parsed = await call(toolset, 'plan_journeys', {
      origin: { kind: 'current_location' },
      destination: { handle: 'place_1' },
      datetimeRepresents: 'arrival',
      requestedAt: '2026-08-21T12:30:00.000Z',
      preferredModes: ['metro', 'rer'],
    });

    expect(parsed.ok).toBe(true);
    expect(parsed.planHandle).toBe('plan_1');
    expect(parsed.journeyCount).toBe(1);

    expect(planner.calls[0]!.input).toMatchObject({
      origin: { latitude: 48.85, longitude: 2.35 },
      destination: { kind: 'station', id: 'stop_chatelet' },
      datetimeRepresents: 'arrival',
      requestedAt: '2026-08-21T12:30:00.000Z',
      preferredModes: ['metro', 'rer'],
      limit: 4,
    });

    const plan = registry.resolvePlan('plan_1');
    expect(plan?.interpretation.datetimeRepresents).toBe('arrival');
    expect(plan?.interpretation.originLabel).toBe('Ma position');
  });

  test('defaults requestedAt to the temporal context when omitted or "now"', async () => {
    const { toolset, planner } = buildToolset();
    await call(toolset, 'search_places', { query: 'Châtelet' });
    await call(toolset, 'plan_journeys', {
      origin: { kind: 'current_location' },
      destination: { handle: 'place_1' },
      datetimeRepresents: 'departure',
      requestedAt: 'now',
    });

    expect(planner.calls[0]!.input.requestedAt).toBe(NOW.toISOString());
  });

  test('rejects an unknown destination handle', async () => {
    const { toolset, planner } = buildToolset();
    const parsed = await call(toolset, 'plan_journeys', {
      origin: { kind: 'current_location' },
      destination: { handle: 'place_999' },
      datetimeRepresents: 'departure',
    });

    expect(parsed.ok).toBe(false);
    expect(parsed.error).toContain('destination inconnu');
    expect(toolset.guardrailTriggered()).toBe(true);
    expect(planner.calls).toHaveLength(0);
  });

  test('refuses current location when the device has none', async () => {
    const { toolset } = buildToolset({ currentLocation: undefined });
    await call(toolset, 'search_places', { query: 'Châtelet' });
    const parsed = await call(toolset, 'plan_journeys', {
      origin: { kind: 'current_location' },
      destination: { handle: 'place_1' },
      datetimeRepresents: 'departure',
    });

    expect(parsed.ok).toBe(false);
    expect(parsed.error).toContain('Position actuelle');
  });

  test('refuses more than the plan budget', async () => {
    const { toolset } = buildToolset();
    await call(toolset, 'search_places', { query: 'Châtelet' });
    for (let i = 0; i < MAX_PLANS; i += 1) {
      await call(toolset, 'plan_journeys', {
        origin: { kind: 'current_location' },
        destination: { handle: 'place_1' },
        datetimeRepresents: 'departure',
      });
    }
    const overrun = await call(toolset, 'plan_journeys', {
      origin: { kind: 'current_location' },
      destination: { handle: 'place_1' },
      datetimeRepresents: 'departure',
    });

    expect(overrun.ok).toBe(false);
    expect(overrun.error).toContain('Budget de calcul');
  });

  test('a handle origin carries originStationId for a station', async () => {
    const { toolset, planner } = buildToolset();
    await call(toolset, 'search_places', { query: 'Châtelet' });
    await call(toolset, 'plan_journeys', {
      origin: { kind: 'handle', handle: 'place_1' },
      destination: { handle: 'place_2' },
      datetimeRepresents: 'departure',
    });

    expect(planner.calls[0]!.input.originStationId).toBe('stop_chatelet');
  });
});

describe('tool guardrails', () => {
  test('an unknown tool name is refused', async () => {
    const { toolset } = buildToolset();
    const parsed = await call(toolset, 'delete_everything', {});

    expect(parsed.ok).toBe(false);
    expect(parsed.error).toContain('Outil inconnu');
    expect(toolset.guardrailTriggered()).toBe(true);
  });

  test('malformed JSON arguments are refused', async () => {
    const { toolset } = buildToolset();
    const parsed = JSON.parse(await toolset.runTool('search_places', '{ not json'));

    expect(parsed.ok).toBe(false);
    expect(parsed.error).toContain('JSON invalides');
  });
});
