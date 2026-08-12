import { expect, test } from 'bun:test';
import { readFileSync } from 'node:fs';

const sourceRoot = new URL('.', import.meta.url).pathname;

test('source modules stay below 300 lines', () => {
  const oversized = [...new Bun.Glob('**/*.{ts,tsx}').scanSync(sourceRoot)]
    .filter((path) => !/\.test\.tsx?$/.test(path))
    .map((path) => ({ path, lines: readFileSync(`${sourceRoot}${path}`, 'utf8').split('\n').length }))
    .filter(({ lines }) => lines > 300);

  expect(oversized).toEqual([]);
});

test('home-map modules export at most one function', () => {
  const violations = [...new Bun.Glob('features/home-map/**/*.{ts,tsx}').scanSync(sourceRoot)]
    .filter((path) => !/\.test\.tsx?$/.test(path))
    .map((path) => ({
      path,
      count: readFileSync(`${sourceRoot}${path}`, 'utf8').match(/export\s+(?:default\s+)?function\s/g)
        ?.length ?? 0,
    }))
    .filter(({ count }) => count > 1);

  expect(violations).toEqual([]);
});
