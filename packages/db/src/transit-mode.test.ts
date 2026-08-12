import { describe, expect, test } from 'bun:test';

import { networkMode, ROUTE_TYPE } from './transit-mode';

describe('networkMode', () => {
  test('keeps every metro and bus route', () => {
    expect(networkMode(ROUTE_TYPE.metro, '14')).toBe('metro');
    expect(networkMode(ROUTE_TYPE.bus, '91')).toBe('bus');
  });

  test('keeps RER A–E without pulling every regional train onto the map', () => {
    expect(networkMode(ROUTE_TYPE.rail, 'A')).toBe('rer');
    expect(networkMode(ROUTE_TYPE.rail, ' e ')).toBe('rer');
    expect(networkMode(ROUTE_TYPE.rail, 'H')).toBeUndefined();
    expect(networkMode(ROUTE_TYPE.rail, 'TER')).toBeUndefined();
  });
});
