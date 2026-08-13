import type { Journey, JourneySection } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';

type JourneyLegStripProps = {
  compact?: boolean;
  journey: Journey;
};

export function JourneyLegStrip({ compact = false, journey }: JourneyLegStripProps) {
  const { colors } = useHomeMapTheme();
  const legs = visibleLegs(journey.sections);

  return (
    <View style={styles.container}>
      {legs.map((section, index) => {
        const minutes = Math.max(1, Math.round(section.durationSeconds / 60));
        const key = `${section.type}:${section.from.name}:${section.to.name}:${index}`;

        if (section.type !== 'transit' || !section.route) {
          return (
            <View
              key={key}
              style={[
                styles.leg,
                compact ? styles.compactLeg : styles.regularLeg,
                { backgroundColor: colors.line },
              ]}>
              <SymbolIcon color={colors.muted} name="figure.walk" size={compact ? 12 : 13} />
              <Text style={[styles.walkLabel, { color: colors.muted }]}>{minutes}</Text>
            </View>
          );
        }

        const icon = section.route.mode === 'bus' ? 'bus.fill' : 'tram.fill';
        return (
          <View
            key={key}
            style={[
              styles.leg,
              compact ? styles.compactLeg : styles.regularLeg,
              styles.transit,
              { backgroundColor: section.route.color },
            ]}>
            <SymbolIcon color={section.route.textColor} name={icon} size={compact ? 12 : 13} />
            <Text
              numberOfLines={1}
              style={[styles.routeLabel, { color: section.route.textColor }]}>
              {section.route.shortName}
            </Text>
            <Text
              style={[
                compact ? styles.compactMinutes : styles.minutes,
                { color: section.route.textColor },
              ]}>
              {minutes} min
            </Text>
          </View>
        );
      })}
    </View>
  );
}

function visibleLegs(sections: JourneySection[]) {
  const travel = sections.filter(
    (section) => section.type === 'walk' || section.type === 'transit'
  );
  if (travel.length <= 3) return travel;

  const firstWalk = travel.find((section) => section.type === 'walk');
  const transit = travel.find((section) => section.type === 'transit');
  const lastWalk = travel.findLast((section) => section.type === 'walk');
  return [firstWalk, transit, lastWalk].filter(
    (section, index, selected): section is JourneySection =>
      Boolean(section) && selected.indexOf(section) === index
  );
}

const styles = StyleSheet.create({
  container: {
    minWidth: 0,
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
  },
  leg: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 5,
    borderCurve: 'continuous',
  },
  regularLeg: { height: 38, minWidth: 50, paddingHorizontal: 11, borderRadius: 10 },
  compactLeg: { height: 38, minWidth: 47, paddingHorizontal: 10, borderRadius: 10 },
  transit: { flexShrink: 1 },
  walkLabel: {
    fontFamily: 'Inter_500Medium',
    fontSize: 14,
    fontVariant: ['tabular-nums'],
  },
  routeLabel: {
    flexShrink: 1,
    fontFamily: 'Inter_700Bold',
    fontSize: 14,
  },
  minutes: {
    fontFamily: 'Inter_700Bold',
    fontSize: 14,
    fontVariant: ['tabular-nums'],
  },
  compactMinutes: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 13,
    fontVariant: ['tabular-nums'],
  },
});
