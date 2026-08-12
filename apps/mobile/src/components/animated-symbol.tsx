import { Image, type SFSymbolEffect } from 'expo-image';
import { useEffect, useState } from 'react';
import { StyleSheet } from 'react-native';

type AnimatedSymbolProps = {
  color: string;
  effect: SFSymbolEffect;
  name: string;
  replayIntervalMs?: number;
  size: number;
};

export function AnimatedSymbol({
  color,
  effect,
  name,
  replayIntervalMs,
  size,
}: AnimatedSymbolProps) {
  const [animationKey, setAnimationKey] = useState(0);

  useEffect(() => {
    if (!replayIntervalMs) return;

    const interval = setInterval(() => {
      setAnimationKey((key) => key + 1);
    }, replayIntervalMs);

    return () => clearInterval(interval);
  }, [replayIntervalMs]);

  return (
    <Image
      key={animationKey}
      source={`sf:${name}`}
      sfEffect={effect}
      style={[styles.symbol, { color, fontSize: size }]}
    />
  );
}

const styles = StyleSheet.create({
  symbol: {
    fontWeight: '600',
  },
});
