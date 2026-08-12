import { describe, expect, test } from 'bun:test';

import { transitBadgeFrame } from '@/components/map/transit-badge-shape';

describe('transitBadgeFrame', () => {
  test('keeps metro badges circular', () => {
    expect(transitBadgeFrame('metro', 20)).toEqual({
      borderRadius: 10,
      height: 20,
      minWidth: 20,
      width: 20,
    });
  });

  test('makes RER badges square', () => {
    expect(transitBadgeFrame('rer', 20)).toEqual({
      borderRadius: 3.2,
      height: 20,
      minWidth: 20,
      width: 20,
    });
  });

  test('gives bus badges a rectangular minimum frame', () => {
    expect(transitBadgeFrame('bus', 20)).toEqual({
      borderRadius: 3.2,
      height: 20,
      minWidth: 28,
    });
  });
});
