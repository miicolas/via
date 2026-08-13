import { describe, expect, test } from 'bun:test';

import { homeFlowReducer, INITIAL_HOME_FLOW } from './home-flow';

describe('home flow', () => {
  test('moves through search, planning, results and detail', () => {
    const search = homeFlowReducer(INITIAL_HOME_FLOW, {
      type: 'query-changed',
      hasQuery: true,
    });
    const planning = homeFlowReducer(search, { type: 'destination-selected' });
    const results = homeFlowReducer(planning, { type: 'planning-settled' });
    const detail = homeFlowReducer(results, { type: 'open-detail', index: 2 });

    expect([search.screen, planning.screen, results.screen, detail.screen]).toEqual([
      'search',
      'planning',
      'results',
      'detail',
    ]);
    expect(detail.selectedJourneyIndex).toBe(2);
    expect(homeFlowReducer(detail, { type: 'close-detail' }).screen).toBe('results');
  });

  test('ignores a stale planning completion outside planning', () => {
    expect(
      homeFlowReducer({ screen: 'search', selectedJourneyIndex: 0 }, {
        type: 'planning-settled',
      })
    ).toEqual({ screen: 'search', selectedJourneyIndex: 0 });
  });
});
