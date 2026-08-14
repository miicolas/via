import { expect, test } from 'bun:test';

import { contract } from './index';
import { rpcMethod } from './methods';

type ContractNode = Record<string, unknown>;

function collectRoutes(node: ContractNode, path: string[]): Array<[string[], string]> {
  if ('~orpc' in node) {
    const route = (node as { '~orpc': { route?: { method?: string } } })['~orpc'].route;
    return [[path, route?.method ?? 'GET']];
  }
  return Object.entries(node).flatMap(([key, child]) =>
    collectRoutes(child as ContractNode, [...path, key])
  );
}

test('rpcMethod mirrors the method declared by every relation route', () => {
  const routes = collectRoutes(contract as ContractNode, []);
  expect(routes.length).toBeGreaterThan(0);
  for (const [path, method] of routes) {
    expect(`${path.join('.')}: ${rpcMethod(path)}`).toBe(`${path.join('.')}: ${method}`);
  }
});
