import type { JourneySection } from '@via/contract';
import { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useReducedMotion,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';

import { LineBadge } from '@/components/map/line-badge';
import { SymbolIcon } from '@/components/symbol-icon';
import { JourneyDisruptionNote } from '@/features/journey/components/disruption-note';
import { JourneyStopsList } from '@/features/journey/components/stops-list';
import { JourneyTimelineRow } from '@/features/journey/components/timeline-row';
import { intermediateStops } from '@/features/journey/model/intermediate-stops';
import { transitStepMeta } from '@/features/journey/model/step-meta';
import { useAppTheme } from '@/hooks/use-app-theme';

type JourneyTransitStepProps = {
  last: boolean;
  minutes: number;
  /** A transit section; the timeline mapper never routes another type here. */
  section: JourneySection;
  stopCount?: number;
  warning?: string;
};

/** A ride on one line: badge, headsign, departure facts, and the stops on demand. */
export function JourneyTransitStep({
  last,
  minutes,
  section,
  stopCount,
  warning,
}: JourneyTransitStepProps) {
  const { colors } = useAppTheme();
  const reduceMotion = useReducedMotion();
  const [expanded, setExpanded] = useState(false);
  const rotation = useSharedValue(0);
  const chevronStyle = useAnimatedStyle(() => ({
    transform: [{ rotate: `${rotation.value * 180}deg` }],
  }));

  const stops = intermediateStops(section);
  const direction = section.direction ?? section.to.name;

  return (
    <JourneyTimelineRow color={section.route?.color ?? colors.primary} last={last} marker="dot">
      <View style={styles.header}>
        {section.route ? (
          <LineBadge route={section.route} size={26} />
        ) : (
          <SymbolIcon color={colors.primary} name="tram.fill" size={22} />
        )}
        <Text numberOfLines={2} selectable style={[styles.title, { color: colors.ink }]}>
          Direction {direction}
        </Text>
        {stops.length > 0 ? (
          <Pressable
            accessibilityHint="Affiche les arrêts intermédiaires"
            accessibilityLabel={`${stopCount} arrêts`}
            accessibilityRole="button"
            accessibilityState={{ expanded }}
            hitSlop={10}
            onPress={() => {
              rotation.value = withTiming(expanded ? 0 : 1, {
                duration: reduceMotion ? 0 : 180,
              });
              setExpanded((value) => !value);
            }}
            style={styles.toggle}>
            <Animated.View style={chevronStyle}>
              <SymbolIcon color={colors.muted} name="chevron.down" size={13} />
            </Animated.View>
          </Pressable>
        ) : null}
      </View>
      <Text style={[styles.meta, { color: colors.muted }]}>
        {transitStepMeta({
          departureAt: section.departureAt,
          minutes,
          platform: section.platform,
          stopCount,
        })}
      </Text>
      {expanded ? <JourneyStopsList stops={stops} /> : null}
      <Text
        numberOfLines={2}
        selectable
        style={[styles.arrival, { borderTopColor: colors.hairline, color: colors.muted }]}>
        Descends à{' '}
        <Text style={[styles.arrivalStop, { color: colors.ink }]}>{section.to.name}</Text>
      </Text>
      {warning ? <JourneyDisruptionNote text={warning} tone="critical" /> : null}
    </JourneyTimelineRow>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  title: { minWidth: 0, flex: 1, fontFamily: 'Inter_600SemiBold', fontSize: 15, lineHeight: 19 },
  toggle: { width: 24, height: 24, alignItems: 'center', justifyContent: 'center' },
  meta: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    lineHeight: 18,
    fontVariant: ['tabular-nums'],
  },
  arrival: {
    marginTop: 4,
    paddingTop: 9,
    borderTopWidth: StyleSheet.hairlineWidth,
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    lineHeight: 17,
  },
  arrivalStop: { fontFamily: 'Inter_600SemiBold' },
});
