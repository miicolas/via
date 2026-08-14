import { describe, expect, test } from 'bun:test';

import {
  resolveButtonHostStyle,
  resolveButtonLabelLayout,
  resolveButtonMatchContents,
} from '@/components/button-layout';

describe('button layout bridge', () => {
  test('measures custom full-width content back into the React Native layout', () => {
    expect(resolveButtonMatchContents(true)).toEqual({
      content: true,
      outer: { vertical: true },
    });
  });

  test('pins an expanding host to a wrapped custom content height', () => {
    expect(resolveButtonHostStyle(true, 81)).toEqual({ height: 81 });
    expect(resolveButtonHostStyle(false, 81)).toBeUndefined();
    expect(resolveButtonHostStyle(true, undefined)).toBeUndefined();
  });

  test('keeps native labels compact and on one line', () => {
    expect(resolveButtonLabelLayout(true, false)).toEqual({
      fontSize: 15,
      maxLines: 1,
      weight: 'semibold',
    });
    expect(resolveButtonLabelLayout(false, false)).toBeUndefined();
    expect(resolveButtonLabelLayout(true, true)).toBeUndefined();
  });
});
