import {
  SymbolView,
  type AnimationSpec,
  type AnimationType,
  type SymbolViewProps,
  type SymbolWeight,
} from 'expo-symbols';
import { useEffect, useState } from 'react';
import type { ColorValue, StyleProp, ViewStyle } from 'react-native';

type SymbolProps = {
  /** Omit for a static symbol. Either an effect type (`'bounce'`) or a full `AnimationSpec`. */
  animation?: AnimationType | AnimationSpec;
  color: ColorValue;
  name: SymbolViewProps['name'];
  /** Remounts the symbol on this interval so a one-shot animation plays again. */
  replayIntervalMs?: number;
  size: number;
  style?: StyleProp<ViewStyle>;
  weight?: SymbolWeight;
};

export function Symbol({
  animation,
  color,
  name,
  replayIntervalMs,
  size,
  style,
  weight = 'semibold',
}: SymbolProps) {
  const [replayKey, setReplayKey] = useState(0);
  const replaying = Boolean(animation && replayIntervalMs);

  useEffect(() => {
    if (!replaying) return;

    const interval = setInterval(() => {
      setReplayKey((key) => key + 1);
    }, replayIntervalMs);

    return () => clearInterval(interval);
  }, [replaying, replayIntervalMs]);

  return (
    <SymbolView
      animationSpec={typeof animation === 'string' ? { effect: { type: animation } } : animation}
      key={replayKey}
      name={name}
      size={size}
      style={style}
      tintColor={color}
      weight={weight}
    />
  );
}
