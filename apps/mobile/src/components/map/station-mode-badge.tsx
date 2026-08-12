import type { NetworkMode } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

import { transitBadgeFrame } from '@/components/map/transit-badge-shape';

const BADGE_SIZE = 24;

const MODE_STYLE: Record<
  NetworkMode,
  { background: string; color: string; fontSize: number; label: string; lineHeight: number }
> = {
  metro: {
    background: 'rgba(4,10,9,0.94)',
    color: '#F2F5F7',
    fontSize: 15,
    label: 'M',
    lineHeight: 17,
  },
  rer: {
    background: 'rgba(242,245,247,0.96)',
    color: '#111827',
    fontSize: 8,
    label: 'RER',
    lineHeight: 10,
  },
  bus: {
    background: 'rgba(33,105,175,0.96)',
    color: '#FFFFFF',
    fontSize: 10,
    label: 'BUS',
    lineHeight: 12,
  },
};

type StationModeBadgeProps = { mode: NetworkMode };

/** Compact mode identity shared by metro, RER and bus stop markers. */
export function StationModeBadge({ mode }: StationModeBadgeProps) {
  const appearance = MODE_STYLE[mode];

  return (
    <View
      style={[
        styles.badge,
        transitBadgeFrame(mode, BADGE_SIZE),
        {
          backgroundColor: appearance.background,
          paddingHorizontal: mode === 'bus' ? 5 : 0,
        },
      ]}>
      <Text
        style={[
          styles.label,
          {
            color: appearance.color,
            fontSize: appearance.fontSize,
            lineHeight: appearance.lineHeight,
          },
        ]}>
        {appearance.label}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    alignItems: 'center',
    justifyContent: 'center',
    borderCurve: 'continuous',
    borderWidth: 1.5,
    borderColor: '#F2F5F7',
    boxShadow: '0 1px 3px rgba(0,0,0,0.35)',
  },
  label: {
    fontFamily: 'Archivo_800ExtraBold',
  },
});
