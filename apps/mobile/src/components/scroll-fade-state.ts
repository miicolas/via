export type ScrollFadeMetrics = {
  contentLength: number;
  endInset: number;
  offset: number;
  startInset: number;
  viewportLength: number;
};

export type ScrollFadeState = {
  bottom: boolean;
  top: boolean;
};

const SCROLL_FADE_EPSILON = 2;

export function scrollFadeState({
  contentLength,
  endInset,
  offset,
  startInset,
  viewportLength,
}: ScrollFadeMetrics): ScrollFadeState {
  const scrollableLength = Math.max(
    0,
    contentLength + startInset + endInset - viewportLength
  );
  const position = Math.min(scrollableLength, Math.max(0, offset + startInset));

  return {
    bottom: scrollableLength - position > SCROLL_FADE_EPSILON,
    top: position > SCROLL_FADE_EPSILON,
  };
}
