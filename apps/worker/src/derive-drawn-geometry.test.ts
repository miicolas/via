import { expect, test } from 'bun:test';

import { deriveDrawnGeometryByRoute } from './derive-drawn-geometry';

test('bounds PostGIS work to one route at a time', async () => {
  let active = 0;
  let peak = 0;
  const completed: string[] = [];

  await deriveDrawnGeometryByRoute(['A', 'B', 'C'], async (routeId) => {
    active += 1;
    peak = Math.max(peak, active);
    await Bun.sleep(1);
    completed.push(routeId);
    active -= 1;
  });

  expect(peak).toBe(1);
  expect(completed).toEqual(['A', 'B', 'C']);
});

test('identifies the route that fails', async () => {
  await expect(
    deriveDrawnGeometryByRoute(['A', 'B'], async (routeId) => {
      if (routeId === 'B') throw new Error('statement timeout');
    })
  ).rejects.toThrow('Could not compute drawn geometry for route B: statement timeout');
});
