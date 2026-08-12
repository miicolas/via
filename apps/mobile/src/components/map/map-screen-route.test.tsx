import { afterAll, beforeAll, expect, mock, test } from 'bun:test';

const routeStack = ['index'];
const navigate = mock((route: string) => {
  if (routeStack.at(-1) !== route) routeStack.push(route);
});
const push = mock((route: string) => routeStack.push(route));

beforeAll(() => {
  mock.module('react', () => ({
    useEffect: (effect: () => void) => {
      effect();
      effect();
    },
  }));
  mock.module('react/jsx-dev-runtime', () => ({
    jsxDEV: (type: unknown, props: Record<string, unknown>) => ({ type, props }),
  }));
  mock.module('react/jsx-runtime', () => ({
    jsx: (type: unknown, props: Record<string, unknown>) => ({ type, props }),
  }));
  mock.module('expo-router', () => ({
    useRouter: () => ({ navigate, push }),
  }));
  mock.module('@/components/map/metro-map-screen', () => ({
    MetroMapScreen: 'MetroMapScreen',
  }));
});

afterAll(() => mock.restore());

test('initializing the map twice keeps a single overview sheet in the route stack', async () => {
  routeStack.splice(0, routeStack.length, 'index');

  const { default: MapScreen } = await import('@/app/(app)/(tabs)/map');
  MapScreen();

  expect(routeStack.filter((route) => route === '/map/overview')).toHaveLength(1);
});
