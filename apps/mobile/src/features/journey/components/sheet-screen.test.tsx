import { afterAll, beforeAll, expect, mock, test } from 'bun:test';

type ElementNode = {
  type: unknown;
  props: Record<string, unknown> & { children?: unknown };
};

const jsx = (type: unknown, props: Record<string, unknown>): ElementNode => ({ type, props });
const cancelJourney = mock(() => undefined);
const resetViaChat = mock(() => undefined);

beforeAll(() => {
  mock.module('react/jsx-dev-runtime', () => ({ Fragment: 'Fragment', jsxDEV: jsx }));
  mock.module('react/jsx-runtime', () => ({ Fragment: 'Fragment', jsx, jsxs: jsx }));
  mock.module('react-native', () => ({
    StyleSheet: { create: (styles: Record<string, unknown>) => styles },
    View: 'View',
  }));
  mock.module('@/features/journey/components/detail', () => ({
    JourneyDetail: 'JourneyDetail',
  }));
  mock.module('@/features/journey/components/results', () => ({
    JourneyResults: 'JourneyResults',
  }));
  mock.module('@/features/journey/components/search-header', () => ({
    JourneySearchHeader: 'JourneySearchHeader',
  }));
  mock.module('@/features/journey/components/natural-journey-status', () => ({
    NaturalJourneyStatus: 'NaturalJourneyStatus',
  }));
  mock.module('@/features/map/hooks/use-map', () => ({
    useMap: () => ({
      cancelJourney,
      closeJourneyDetail: () => undefined,
      journey: { status: 'planning' },
      journeyDestination: {
        kind: 'station',
        id: 'chatelet',
        name: 'Châtelet',
        coordinate: { latitude: 48.858, longitude: 2.347 },
      },
      naturalJourney: { status: 'ready', response: {} },
      openJourneyDetail: () => undefined,
      retryJourney: () => undefined,
      resolveNaturalJourney: () => undefined,
      searchQuery: 'Châtelet avant 10h',
      screen: 'results',
      selectedJourneyIndex: 0,
    }),
  }));
  mock.module('@/features/chat/hooks/use-via-chat-context', () => ({
    useViaChatContext: () => ({ reset: resetViaChat }),
  }));
});

afterAll(() => mock.restore());

test('keeps the complete natural search phrase in the journey header', async () => {
  const { JourneySheetScreen } = await import('./sheet-screen');
  const tree = JourneySheetScreen() as unknown as ElementNode;
  const header = (tree.props.children as ElementNode[])[0];

  expect(header.type).toBe('JourneySearchHeader');
  expect(header.props.destination).toBe('Châtelet avant 10h');
});

test('the journey header cross clears Via and cancels the whole search', async () => {
  const { JourneySheetScreen } = await import('./sheet-screen');
  const tree = JourneySheetScreen() as unknown as ElementNode;
  const header = (tree.props.children as ElementNode[])[0];

  (header.props.onCancel as () => void)();

  expect(resetViaChat).toHaveBeenCalledTimes(1);
  expect(cancelJourney).toHaveBeenCalledTimes(1);
});
