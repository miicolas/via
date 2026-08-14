import type { Coordinate, Journey, JourneyDestination } from '@via/contract';

import { isJourneyScreen } from './journey-screen';
import {
  MAP_JOURNEY_DETAIL_SHEET_INITIAL_DETENT_INDEX,
  MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
  MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
} from './overview-sheet';

export type FlowScreen = 'overview' | 'search' | 'planning' | 'clarification' | 'results' | 'detail';

export type SelectedPlace = {
  name: string;
  coordinate: Coordinate;
};

export type MapFocusTarget =
  | {
      kind: 'station';
      stationId: string;
      coordinate: Coordinate;
    }
  | {
      kind: 'journey';
      journey: Journey;
    };

/** A fresh intent object is a fresh instruction; consumers key on its identity. */
export type MapFocusIntent = MapFocusTarget & { detentIndex: number };

export type MapFlowState = {
  screen: FlowScreen;
  searchFocused: boolean;
  searchQuery: string;
  selectedJourneyIndex: number;
  overviewDetentIndex: number;
  selectedStationId?: string;
  selectedPlace?: SelectedPlace;
  journeyDestination?: JourneyDestination;
  journeyDistanceMeters?: number;
  journeyRetry: number;
  focusIntent?: MapFocusIntent;
};

export type MapFlowEvent =
  | {
      type: 'search-focus-changed';
      focused: boolean;
    }
  | {
      type: 'query-changed';
      query: string;
    }
  | {
      type: 'station-selected';
      stationId: string;
      journeyDestination?: JourneyDestination;
      journeyDistanceMeters?: number;
      focusCoordinate?: Coordinate;
    }
  | {
      type: 'address-selected';
      place: SelectedPlace;
      journeyDestination: JourneyDestination;
      journeyDistanceMeters?: number;
    }
  | { type: 'planning-settled' }
  | { type: 'natural-journey-submitted' }
  | { type: 'natural-journey-needs-clarification' }
  | { type: 'natural-journey-ready'; destination: JourneyDestination }
  | { type: 'natural-journey-failed' }
  | { type: 'journey-detail-opened'; index: number }
  | { type: 'journey-detail-closed' }
  | { type: 'journey-retried' }
  | { type: 'journey-cancelled' }
  | {
      type: 'station-focus-available';
      stationId: string;
      coordinate: Coordinate;
    }
  | { type: 'journey-focus-available'; journey: Journey }
  | { type: 'detent-changed'; index: number };

export const INITIAL_MAP_FLOW: MapFlowState = {
  screen: 'overview',
  searchFocused: false,
  searchQuery: '',
  selectedJourneyIndex: 0,
  overviewDetentIndex: MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
  journeyRetry: 0,
};

/** Owns every synchronous transition of the resident map and sheet flow. */
export function transitionMapFlow(
  state: MapFlowState,
  event: MapFlowEvent
): MapFlowState {
  switch (event.type) {
    case 'search-focus-changed': {
      const hasQuery = state.searchQuery.trim().length > 0;
      const active = event.focused || hasQuery;

      return {
        ...state,
        screen: active ? 'search' : 'overview',
        searchFocused: event.focused,
        overviewDetentIndex: event.focused
          ? MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX
          : hasQuery
            ? state.overviewDetentIndex
            : MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
      };
    }
    case 'query-changed':
      return {
        ...state,
        screen: event.query.trim().length > 0 || state.searchFocused ? 'search' : 'overview',
        searchQuery: event.query,
        selectedJourneyIndex: 0,
        selectedStationId: undefined,
        selectedPlace: undefined,
        journeyDestination: undefined,
        journeyDistanceMeters: undefined,
      };
    case 'station-selected': {
      const plansJourney = event.journeyDestination !== undefined;
      const next: MapFlowState = {
        ...state,
        screen: plansJourney ? 'planning' : 'overview',
        searchFocused: false,
        selectedJourneyIndex: 0,
        selectedStationId: event.stationId,
        selectedPlace: undefined,
        journeyDestination: event.journeyDestination,
        journeyDistanceMeters: event.journeyDistanceMeters,
        focusIntent: undefined,
        overviewDetentIndex: plansJourney
          ? MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX
          : MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
      };
      return event.focusCoordinate
        ? withFocus(
            next,
            { kind: 'station', stationId: event.stationId, coordinate: event.focusCoordinate },
            true
          )
        : next;
    }
    case 'address-selected':
      return {
        ...state,
        screen: 'planning',
        searchFocused: false,
        selectedJourneyIndex: 0,
        selectedStationId: undefined,
        selectedPlace: event.place,
        journeyDestination: event.journeyDestination,
        journeyDistanceMeters: event.journeyDistanceMeters,
        focusIntent: undefined,
        overviewDetentIndex: MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
      };
    case 'planning-settled':
      return state.screen === 'planning' ? { ...state, screen: 'results' } : state;
    case 'natural-journey-submitted':
      return {
        ...state,
        screen: 'planning',
        searchFocused: false,
        selectedJourneyIndex: 0,
        selectedStationId: undefined,
        selectedPlace: undefined,
        journeyDestination: undefined,
        journeyDistanceMeters: undefined,
        overviewDetentIndex: MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
      };
    case 'natural-journey-needs-clarification':
      return state.screen === 'planning' ? { ...state, screen: 'clarification' } : state;
    case 'natural-journey-ready':
      return {
        ...state,
        screen: 'results',
        searchFocused: false,
        journeyDestination: event.destination,
        selectedJourneyIndex: 0,
        overviewDetentIndex: MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
      };
    case 'natural-journey-failed':
      return {
        ...state,
        screen: 'search',
        searchFocused: false,
        journeyDestination: undefined,
      };
    case 'journey-detail-opened':
      return {
        ...state,
        screen: 'detail',
        selectedJourneyIndex: event.index,
        overviewDetentIndex: MAP_JOURNEY_DETAIL_SHEET_INITIAL_DETENT_INDEX,
        focusIntent: undefined,
      };
    case 'journey-detail-closed':
      return {
        ...state,
        screen: 'results',
        overviewDetentIndex: MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
        focusIntent: undefined,
      };
    case 'journey-retried':
      return {
        ...state,
        screen: 'planning',
        selectedJourneyIndex: 0,
        overviewDetentIndex: MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
        journeyRetry: state.journeyRetry + 1,
        focusIntent: undefined,
      };
    case 'journey-cancelled': {
      return {
        ...state,
        screen: 'overview',
        searchFocused: false,
        searchQuery: '',
        selectedJourneyIndex: 0,
        selectedStationId: undefined,
        selectedPlace: undefined,
        journeyDestination: undefined,
        journeyDistanceMeters: undefined,
        focusIntent: undefined,
        overviewDetentIndex: MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
      };
    }
    case 'station-focus-available':
      return isJourneyScreen(state.screen)
        ? state
        : withFocus(state, {
            kind: 'station',
            stationId: event.stationId,
            coordinate: event.coordinate,
          });
    case 'journey-focus-available':
      return state.screen === 'results' || state.screen === 'detail'
        ? withFocus(state, { kind: 'journey', journey: event.journey })
        : state;
    case 'detent-changed': {
      const moved = {
        ...state,
        overviewDetentIndex: Math.max(0, event.index),
      };
      const intent = state.focusIntent;
      if (!intent) return moved;
      const replays =
        intent.kind === 'station'
          ? !isJourneyScreen(state.screen)
          : state.screen === 'results' || state.screen === 'detail';
      return replays ? withFocus(moved, intent, true) : moved;
    }
  }
}

/**
 * Repeats of the current target at the current detent keep the same state (and
 * intent object), so the map is not re-animated; `force` mints a fresh intent
 * to replay the focus after detent moves and repeated taps.
 */
function withFocus(state: MapFlowState, target: MapFocusTarget, force = false): MapFlowState {
  const current = state.focusIntent;
  if (
    !force &&
    current &&
    sameFocusTarget(current, target) &&
    current.detentIndex === state.overviewDetentIndex
  ) {
    return state;
  }

  return {
    ...state,
    focusIntent: { ...target, detentIndex: state.overviewDetentIndex },
  };
}

function sameFocusTarget(a: MapFocusTarget, b: MapFocusTarget): boolean {
  if (a.kind === 'station' && b.kind === 'station') {
    return (
      a.stationId === b.stationId &&
      a.coordinate.latitude === b.coordinate.latitude &&
      a.coordinate.longitude === b.coordinate.longitude
    );
  }
  return a.kind === 'journey' && b.kind === 'journey' && a.journey.id === b.journey.id;
}
