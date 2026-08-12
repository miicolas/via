import { afterAll, beforeAll, expect, mock, test } from 'bun:test';

type ElementNode = {
  type: unknown;
  props: Record<string, unknown>;
};

beforeAll(() => {
  mock.module('react/jsx-dev-runtime', () => ({
    jsxDEV: (type: unknown, props: Record<string, unknown>) => ({ type, props }),
  }));
  mock.module('react/jsx-runtime', () => ({
    jsx: (type: unknown, props: Record<string, unknown>) => ({ type, props }),
  }));
  mock.module('@/components/map/metro-map-screen', () => ({
    MetroMapScreen: 'MetroMapScreen',
  }));
});

afterAll(() => mock.restore());

test('the map route renders the resident map and sheet screen directly', async () => {
  const { default: MapScreen } = await import('@/app/(app)/(tabs)/map');
  const tree = MapScreen() as unknown as ElementNode;

  expect(tree.type).toBe('MetroMapScreen');
});
