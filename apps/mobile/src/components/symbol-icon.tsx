import {
  SymbolView,
  type AnimationSpec,
  type AnimationType,
  type SymbolViewProps,
  type SymbolWeight,
} from 'expo-symbols';
import { useEffect, useState } from 'react';
import type { ColorValue, StyleProp, ViewStyle } from 'react-native';

type SymbolIconProps = {
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

/**
 * Named `SymbolIcon`, not `Symbol`: importing a binding called `Symbol` shadows the
 * global in that module, and React Compiler's prelude calls
 * `Symbol.for('react.memo_cache_sentinel')` — which would resolve to this component
 * and throw `undefined is not a function` before the consumer renders anything.
 */
export function SymbolIcon({
  animation,
  color,
  name,
  replayIntervalMs,
  size,
  style,
  weight = 'semibold',
}: SymbolIconProps) {
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
