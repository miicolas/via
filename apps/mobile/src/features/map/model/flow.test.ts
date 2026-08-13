import { describe, expect, test } from 'bun:test';

import { flowReducer, INITIAL_HOME_FLOW } from './flow';

describe('home flow', () => {
  test('moves through search, planning, results and detail', () => {
    const search = flowReducer(INITIAL_HOME_FLOW, {
      type: 'query-changed',
      hasQuery: true,
    });
    const planning = flowReducer(search, { type: 'destination-selected' });
    const results = flowReducer(planning, { type: 'planning-settled' });
    const detail = flowReducer(results, { type: 'open-detail', index: 2 });

    expect([search.screen, planning.screen, results.screen, detail.screen]).toEqual([
      'search',
      'planning',
      'results',
      'detail',
    ]);
    expect(detail.selectedJourneyIndex).toBe(2);
    expect(flowReducer(detail, { type: 'close-detail' }).screen).toBe('results');
  });

  test('ignores a stale planning completion outside planning', () => {
    expect(
      flowReducer({ screen: 'search', selectedJourneyIndex: 0 }, {
        type: 'planning-settled',
      })
    ).toEqual({ screen: 'search', selectedJourneyIndex: 0 });
  });
});
