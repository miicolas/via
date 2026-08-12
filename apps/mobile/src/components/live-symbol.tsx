import { Image } from 'expo-image';
import { useEffect, useState } from 'react';
import { StyleSheet } from 'react-native';

type LiveSymbolProps = {
  color?: string;
  intervalMs?: number;
  name?: string;
  size?: number;
};

export function LiveSymbol({
  color = '#2F6B5B',
  intervalMs = 10_000,
  name = 'wave.3.left',
  size = 13,
}: LiveSymbolProps) {
  const [animationKey, setAnimationKey] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => {
      setAnimationKey((key) => key + 1);
    }, intervalMs);

    return () => clearInterval(interval);
  }, [intervalMs]);

  return (
    <Image
      key={animationKey}
      source={`sf:${name}`}
      sfEffect="appear"
      style={[styles.symbol, { color, fontSize: size }]}
    />
  );
}

const styles = StyleSheet.create({
  symbol: {
    fontWeight: '600',
  },
});
