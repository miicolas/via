export type HomeFlowScreen = 'overview' | 'search' | 'planning' | 'results' | 'detail';

export type HomeFlowState = {
  screen: HomeFlowScreen;
  selectedJourneyIndex: number;
};

export type HomeFlowEvent =
  | { type: 'query-changed'; hasQuery: boolean }
  | { type: 'nearby-selected' }
  | { type: 'destination-selected' }
  | { type: 'planning-settled' }
  | { type: 'retry-planning' }
  | { type: 'open-detail'; index: number }
  | { type: 'close-detail' }
  | { type: 'cancel-journey'; hasQuery: boolean };

export const INITIAL_HOME_FLOW: HomeFlowState = {
  screen: 'overview',
  selectedJourneyIndex: 0,
};

/** Pure state machine for the resident map sheet. Network data stays outside it. */
export function homeFlowReducer(state: HomeFlowState, event: HomeFlowEvent): HomeFlowState {
  switch (event.type) {
    case 'query-changed':
      return {
        screen: event.hasQuery ? 'search' : 'overview',
        selectedJourneyIndex: 0,
      };
    case 'nearby-selected':
      return INITIAL_HOME_FLOW;
    case 'destination-selected':
    case 'retry-planning':
      return { screen: 'planning', selectedJourneyIndex: 0 };
    case 'planning-settled':
      return state.screen === 'planning'
        ? { ...state, screen: 'results' }
        : state;
    case 'open-detail':
      return { screen: 'detail', selectedJourneyIndex: event.index };
    case 'close-detail':
      return { ...state, screen: 'results' };
    case 'cancel-journey':
      return {
        screen: event.hasQuery ? 'search' : 'overview',
        selectedJourneyIndex: 0,
      };
  }
}
