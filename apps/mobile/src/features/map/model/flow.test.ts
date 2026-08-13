import { describe, expect, test } from 'bun:test';
import type { Journey } from '@via/contract';

import {
  MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
  MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
} from './overview-sheet';
import { INITIAL_MAP_FLOW, transitionMapFlow } from './flow';

describe('map flow', () => {
  test('a query change clears the selection without moving the sheet', () => {
    const selected = {
      ...INITIAL_MAP_FLOW,
      overviewDetentIndex: 0,
      selectedStationId: 'nation',
      selectedPlace: {
        name: 'Place de la Nation',
        coordinate: { latitude: 48.848, longitude: 2.396 },
      },
      journeyDestination: {
        kind: 'station' as const,
        id: 'nation',
        name: 'Nation',
        coordinate: { latitude: 48.848, longitude: 2.396 },
      },
      journeyDistanceMeters: 4_200,
    };

    const next = transitionMapFlow(selected, {
      type: 'query-changed',
      query: '  Bastille  ',
    });

    expect(next).toMatchObject({
      screen: 'search',
      searchQuery: '  Bastille  ',
      overviewDetentIndex: 0,
      selectedJourneyIndex: 0,
    });
    expect(next.selectedStationId).toBeUndefined();
    expect(next.selectedPlace).toBeUndefined();
    expect(next.journeyDestination).toBeUndefined();
    expect(next.journeyDistanceMeters).toBeUndefined();
  });

  test('a station selection owns the overview or journey transition', () => {
    const nearby = transitionMapFlow(INITIAL_MAP_FLOW, {
      type: 'station-selected',
      stationId: 'republique',
    });
    const destination = {
      kind: 'station' as const,
      id: 'nation',
      name: 'Nation',
      coordinate: { latitude: 48.848, longitude: 2.396 },
    };
    const distant = transitionMapFlow(nearby, {
      type: 'station-selected',
      stationId: 'nation',
      journeyDestination: destination,
      journeyDistanceMeters: 4_200,
    });

    expect(nearby).toMatchObject({
      screen: 'overview',
      selectedStationId: 'republique',
      overviewDetentIndex: MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
    });
    expect(nearby.journeyDestination).toBeUndefined();
    expect(distant).toMatchObject({
      screen: 'planning',
      selectedStationId: 'nation',
      journeyDestination: destination,
      journeyDistanceMeters: 4_200,
      overviewDetentIndex: MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
    });
  });

  test('an address selection starts planning and replaces the station selection', () => {
    const selectedStation = transitionMapFlow(INITIAL_MAP_FLOW, {
      type: 'station-selected',
      stationId: 'republique',
    });
    const coordinate = { latitude: 48.853, longitude: 2.349 };
    const destination = {
      kind: 'address' as const,
      id: 'ban:opera',
      name: 'Place de l’Opéra',
      context: 'Paris 9e',
      coordinate,
    };

    const next = transitionMapFlow(selectedStation, {
      type: 'address-selected',
      place: { name: destination.name, coordinate },
      journeyDestination: destination,
      journeyDistanceMeters: 3_100,
    });

    expect(next).toMatchObject({
      screen: 'planning',
      selectedPlace: { name: 'Place de l’Opéra', coordinate },
      journeyDestination: destination,
      journeyDistanceMeters: 3_100,
      overviewDetentIndex: MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
    });
    expect(next.selectedStationId).toBeUndefined();
  });

  test('journey actions own the selected variant, sheet detent, and retry generation', () => {
    const destination = {
      kind: 'address' as const,
      id: 'ban:opera',
      name: 'Place de l’Opéra',
      coordinate: { latitude: 48.853, longitude: 2.349 },
    };
    const planning = transitionMapFlow(INITIAL_MAP_FLOW, {
      type: 'address-selected',
      place: { name: destination.name, coordinate: destination.coordinate },
      journeyDestination: destination,
    });
    const results = transitionMapFlow(planning, { type: 'planning-settled' });
    const detail = transitionMapFlow(results, { type: 'journey-detail-opened', index: 2 });
    const movedDetail = transitionMapFlow(detail, { type: 'detent-changed', index: 2 });
    const closed = transitionMapFlow(movedDetail, { type: 'journey-detail-closed' });
    const retrying = transitionMapFlow(closed, { type: 'journey-retried' });

    expect(results.screen).toBe('results');
    expect(detail).toMatchObject({
      screen: 'detail',
      selectedJourneyIndex: 2,
      overviewDetentIndex: MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
    });
    expect(movedDetail.overviewDetentIndex).toBe(2);
    expect(closed).toMatchObject({
      screen: 'results',
      overviewDetentIndex: MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
    });
    expect(retrying).toMatchObject({
      screen: 'planning',
      selectedJourneyIndex: 0,
      overviewDetentIndex: MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
      journeyRetry: 1,
    });
  });

  test('cancelling a journey returns to the remaining query or to the overview', () => {
    const searched = transitionMapFlow(INITIAL_MAP_FLOW, {
      type: 'query-changed',
      query: 'Nation',
    });
    const destination = {
      kind: 'address' as const,
      id: 'ban:nation',
      name: 'Place de la Nation',
      coordinate: { latitude: 48.848, longitude: 2.396 },
    };
    const planning = transitionMapFlow(searched, {
      type: 'address-selected',
      place: { name: destination.name, coordinate: destination.coordinate },
      journeyDestination: destination,
    });
    const backToSearch = transitionMapFlow(planning, { type: 'journey-cancelled' });
    const backToOverview = transitionMapFlow(
      { ...planning, searchQuery: '' },
      { type: 'journey-cancelled' }
    );

    expect(backToSearch).toMatchObject({
      screen: 'search',
      searchQuery: 'Nation',
      overviewDetentIndex: MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
      selectedJourneyIndex: 0,
    });
    expect(backToOverview).toMatchObject({
      screen: 'overview',
      overviewDetentIndex: MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
    });
    expect(backToSearch.selectedPlace).toBeUndefined();
    expect(backToSearch.journeyDestination).toBeUndefined();
  });

  test('station focus is declarative, deduplicated, and replayed for a new detent', () => {
    const coordinate = { latitude: 48.867, longitude: 2.364 };
    const focused = transitionMapFlow(INITIAL_MAP_FLOW, {
      type: 'station-focus-available',
      stationId: 'republique',
      coordinate,
    });
    const duplicate = transitionMapFlow(focused, {
      type: 'station-focus-available',
      stationId: 'republique',
      coordinate,
    });
    const moved = transitionMapFlow(duplicate, { type: 'detent-changed', index: 2 });
    const repeatedTap = transitionMapFlow(moved, {
      type: 'station-selected',
      stationId: 'republique',
      focusCoordinate: coordinate,
    });

    expect(focused.focusIntent).toEqual({
      kind: 'station',
      stationId: 'republique',
      coordinate,
      detentIndex: MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
    });
    expect(duplicate).toBe(focused);
    expect(moved.focusIntent).toMatchObject({ kind: 'station', detentIndex: 2 });
    expect(moved.focusIntent).not.toBe(focused.focusIntent);
    expect(repeatedTap.focusIntent).toMatchObject({
      kind: 'station',
      detentIndex: MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
    });
    expect(repeatedTap.focusIntent).not.toBe(moved.focusIntent);
  });

  test('journey focus is issued only from detail and replayed for its detents', () => {
    const journey = { id: 'journey-1' } as Journey;
    const detail = {
      ...INITIAL_MAP_FLOW,
      screen: 'detail' as const,
      selectedJourneyIndex: 1,
    };
    const focused = transitionMapFlow(detail, {
      type: 'journey-focus-available',
      journey,
    });
    const duplicate = transitionMapFlow(focused, {
      type: 'journey-focus-available',
      journey,
    });
    const moved = transitionMapFlow(duplicate, { type: 'detent-changed', index: 2 });
    const ignoredStation = transitionMapFlow(moved, {
      type: 'station-focus-available',
      stationId: 'nation',
      coordinate: { latitude: 48.848, longitude: 2.396 },
    });

    expect(focused.focusIntent).toEqual({
      kind: 'journey',
      journey,
      detentIndex: MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
    });
    expect(duplicate).toBe(focused);
    expect(moved.focusIntent).toMatchObject({ kind: 'journey', detentIndex: 2 });
    expect(moved.focusIntent).not.toBe(focused.focusIntent);
    expect(ignoredStation).toBe(moved);
  });

  test('a journey selection drops an unrelated station focus', () => {
    const focused = transitionMapFlow(INITIAL_MAP_FLOW, {
      type: 'station-focus-available',
      stationId: 'republique',
      coordinate: { latitude: 48.867, longitude: 2.364 },
    });
    const destination = {
      kind: 'address' as const,
      id: 'ban:nation',
      name: 'Place de la Nation',
      coordinate: { latitude: 48.848, longitude: 2.396 },
    };

    const planning = transitionMapFlow(focused, {
      type: 'address-selected',
      place: { name: destination.name, coordinate: destination.coordinate },
      journeyDestination: destination,
    });

    expect(planning.focusIntent).toBeUndefined();
  });

  test('a stale planning completion cannot leave the current screen', () => {
    const search = { ...INITIAL_MAP_FLOW, screen: 'search' as const, searchQuery: 'Nation' };

    expect(transitionMapFlow(search, { type: 'planning-settled' })).toBe(search);
  });
});
