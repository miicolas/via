import { describe, expect, test } from 'bun:test';

import {
  METRO_SHORT_NAMES,
  networkMode,
  RER_SHORT_NAMES,
  ROUTE_TYPE,
  TRAM_SHORT_NAMES,
  TRANSILIEN_SHORT_NAMES,
} from './transit-mode';

describe('networkMode', () => {
  test('keeps the exact metro set and every bus route', () => {
    expect(networkMode(ROUTE_TYPE.metro, '14')).toBe('metro');
    expect(networkMode(ROUTE_TYPE.metro, 'ORLYVAL')).toBeUndefined();
    expect(networkMode(ROUTE_TYPE.metro, 'CDG VAL')).toBeUndefined();
    expect(networkMode(ROUTE_TYPE.bus, '91')).toBe('bus');
  });

  test('keeps RER A–E without pulling every regional train onto the map', () => {
    expect(networkMode(ROUTE_TYPE.rail, 'A')).toBe('rer');
    expect(networkMode(ROUTE_TYPE.rail, ' e ')).toBe('rer');
  });

  test('keeps the exact Transilien letter set', () => {
    for (const line of ['H', 'J', 'K', 'L', 'N', 'P', 'R', 'U', 'V']) {
      expect(networkMode(ROUTE_TYPE.rail, line)).toBe('transilien');
    }
    expect(networkMode(ROUTE_TYPE.rail, 'TER')).toBeUndefined();
  });

  test('keeps T1–T14 while excluding rail shuttles and guided special modes', () => {
    for (const line of TRAM_SHORT_NAMES) {
      expect(networkMode(ROUTE_TYPE.tram, line)).toBe('tram');
    }
    expect(networkMode(ROUTE_TYPE.tram, 'ORLYVAL')).toBeUndefined();
    expect(networkMode(ROUTE_TYPE.tram, 'CDG VAL')).toBeUndefined();
    expect(networkMode(ROUTE_TYPE.funicular, 'FUN')).toBeUndefined();
    expect(networkMode(ROUTE_TYPE.aerialLift, 'C1')).toBeUndefined();
  });

  test('classifies exactly the 45 drawable lines from the current feed scope', () => {
    const classified = [
      ...METRO_SHORT_NAMES.map((line) => networkMode(ROUTE_TYPE.metro, line)),
      ...RER_SHORT_NAMES.map((line) => networkMode(ROUTE_TYPE.rail, line)),
      ...TRAM_SHORT_NAMES.map((line) => networkMode(ROUTE_TYPE.tram, line)),
      ...TRANSILIEN_SHORT_NAMES.map((line) => networkMode(ROUTE_TYPE.rail, line)),
    ];

    expect(classified).toHaveLength(45);
    expect(classified.every(Boolean)).toBe(true);
  });
});
