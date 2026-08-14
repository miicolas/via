import { describe, expect, test } from 'bun:test';

import { scrollFadeState, type ScrollFadeMetrics } from '@/components/scroll-fade-state';

const BASE_METRICS: ScrollFadeMetrics = {
  contentLength: 600,
  endInset: 0,
  offset: 0,
  startInset: 0,
  viewportLength: 200,
};

describe('scroll fade state', () => {
  test('does not fade content that fits in the viewport', () => {
    expect(scrollFadeState({ ...BASE_METRICS, contentLength: 180 })).toEqual({
      bottom: false,
      top: false,
    });
  });

  test('fades only the edge that has more content at either endpoint', () => {
    expect(scrollFadeState(BASE_METRICS)).toEqual({ bottom: true, top: false });
    expect(scrollFadeState({ ...BASE_METRICS, offset: 400 })).toEqual({
      bottom: false,
      top: true,
    });
  });

  test('fades both edges between the endpoints', () => {
    expect(scrollFadeState({ ...BASE_METRICS, offset: 200 })).toEqual({
      bottom: true,
      top: true,
    });
  });

  test('accounts for content insets when locating the endpoints', () => {
    const insetMetrics = { ...BASE_METRICS, endInset: 30, startInset: 20 };

    expect(scrollFadeState({ ...insetMetrics, offset: -20 })).toEqual({
      bottom: true,
      top: false,
    });
    expect(scrollFadeState({ ...insetMetrics, offset: 430 })).toEqual({
      bottom: false,
      top: true,
    });
  });
});
