import type { Ref } from 'react';
import { useEffect, useRef, useState } from 'react';
import {
  ScrollView,
  type ScrollViewProps,
  type NativeScrollEvent,
  type NativeSyntheticEvent,
} from 'react-native';

import { SCROLL_FADE_HEIGHT } from '@/components/scroll-fade-edge';
import { ScrollFadeMask } from '@/components/scroll-fade-mask';
import {
  scrollFadeState,
  type ScrollFadeMetrics,
  type ScrollFadeState,
} from '@/components/scroll-fade-state';

type FadingScrollViewProps = Omit<ScrollViewProps, 'fadingEdgeLength' | 'horizontal'> & {
  ref?: Ref<ScrollView>;
};

const INITIAL_FADE_STATE: ScrollFadeState = { bottom: false, top: false };

/** Vertical ScrollView with platform-consistent fades wherever more content remains. */
export function FadingScrollView({
  contentInset,
  contentOffset,
  onContentSizeChange,
  onLayout,
  onScroll,
  ref,
  scrollEventThrottle,
  ...props
}: FadingScrollViewProps) {
  const metricsRef = useRef<ScrollFadeMetrics>({
    contentLength: 0,
    endInset: contentInset?.bottom ?? 0,
    offset: contentOffset?.y ?? -(contentInset?.top ?? 0),
    startInset: contentInset?.top ?? 0,
    viewportLength: 0,
  });
  const fadeRef = useRef(INITIAL_FADE_STATE);
  const [fade, setFade] = useState(INITIAL_FADE_STATE);

  const syncFade = () => {
    const nextFade = scrollFadeState(metricsRef.current);
    if (nextFade.bottom === fadeRef.current.bottom && nextFade.top === fadeRef.current.top) return;

    fadeRef.current = nextFade;
    setFade(nextFade);
  };

  useEffect(() => {
    metricsRef.current.endInset = contentInset?.bottom ?? 0;
    metricsRef.current.startInset = contentInset?.top ?? 0;
    if (contentOffset?.y !== undefined) metricsRef.current.offset = contentOffset.y;
    syncFade();
  }, [contentInset?.bottom, contentInset?.top, contentOffset?.y]);

  const handleScroll = (event: NativeSyntheticEvent<NativeScrollEvent>) => {
    const { contentInset: nativeInset, contentOffset: nativeOffset, contentSize, layoutMeasurement } =
      event.nativeEvent;
    metricsRef.current = {
      contentLength: contentSize.height,
      endInset: nativeInset.bottom,
      offset: nativeOffset.y,
      startInset: nativeInset.top,
      viewportLength: layoutMeasurement.height,
    };
    syncFade();
    onScroll?.(event);
  };

  return (
    <ScrollFadeMask bottom={fade.bottom} top={fade.top}>
      <ScrollView
        {...props}
        contentInset={contentInset}
        contentOffset={contentOffset}
        fadingEdgeLength={{ start: SCROLL_FADE_HEIGHT, end: SCROLL_FADE_HEIGHT }}
        onContentSizeChange={(width, height) => {
          metricsRef.current.contentLength = height;
          syncFade();
          onContentSizeChange?.(width, height);
        }}
        onLayout={(event) => {
          metricsRef.current.viewportLength = event.nativeEvent.layout.height;
          syncFade();
          onLayout?.(event);
        }}
        onScroll={handleScroll}
        ref={ref}
        scrollEventThrottle={scrollEventThrottle ?? 16}
      />
    </ScrollFadeMask>
  );
}
