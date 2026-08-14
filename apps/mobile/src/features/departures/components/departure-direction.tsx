import type { DeparturesSource } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { AnimatedMinutes } from '@/features/departures/components/animated-minutes';
import type { WaitTimes } from '@/features/departures/model/wait-times';
import { useAppTheme } from '@/hooks/use-app-theme';

type DepartureDirectionProps = {
  destination: string;
  divided: boolean;
  source: DeparturesSource;
  wait?: WaitTimes;
};

const minutesLabel = (minutes: number) => `${minutes} minute${minutes === 1 ? '' : 's'}`;

export function DepartureDirection({
  destination,
  divided,
  source,
  wait,
}: DepartureDirectionProps) {
  const { colors } = useAppTheme();
  const accessibilityTiming = wait
    ? [
        minutesLabel(wait.primaryMinutes),
        wait.followingMinutes?.length
          ? `puis ${wait.followingMinutes.map(minutesLabel).join(' et ')}`
          : undefined,
        source === 'theoretical' ? 'horaires théoriques' : 'temps réel',
      ]
        .filter(Boolean)
        .join(', ')
    : 'aucun passage annoncé';

  return (
    <View
      accessible
      accessibilityLabel={`${destination}, ${accessibilityTiming}`}
      accessibilityRole="text"
      style={[
        styles.direction,
        divided && {
          borderTopColor: colors.line,
          borderTopWidth: StyleSheet.hairlineWidth,
        },
      ]}>
      <View style={styles.destinationBlock}>
        <Text numberOfLines={2} style={[styles.destination, { color: colors.ink }]}>
          {destination}
        </Text>
        {source === 'theoretical' ? (
          <Text style={[styles.theoretical, { color: colors.muted }]}>théorique</Text>
        ) : null}
      </View>
      <View style={styles.passages}>
        {source === 'realtime' && wait ? (
          <SymbolIcon
            animation="pulse"
            color={colors.primary}
            name="wave.3.left"
            replayIntervalMs={10_000}
            size={12}
          />
        ) : null}
        {wait ? (
          <>
            <View style={styles.primaryPassage}>
              <AnimatedMinutes
                appearance="compact"
                color={colors.ink}
                value={wait.primaryMinutes}
              />
              <Text style={[styles.primaryPrime, { color: colors.ink }]}>′</Text>
            </View>
            {wait.followingMinutes?.map((minutes, index) => (
              <Text
                key={`${minutes}-${index}`}
                style={[styles.followingPassage, { color: colors.muted }]}>
                {minutes}′
              </Text>
            ))}
          </>
        ) : (
          <Text numberOfLines={1} style={[styles.unavailable, { color: colors.muted }]}>
            Aucun passage
          </Text>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  direction: {
    minHeight: 44,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingVertical: 2,
  },
  destinationBlock: { flex: 1, minWidth: 0 },
  destination: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 14,
    lineHeight: 18,
  },
  theoretical: {
    fontFamily: 'Inter_400Regular',
    fontSize: 10,
    lineHeight: 12,
  },
  passages: {
    minWidth: 118,
    flexDirection: 'row',
    alignItems: 'baseline',
    justifyContent: 'flex-end',
    gap: 5,
  },
  primaryPassage: {
    flexDirection: 'row',
    alignItems: 'baseline',
  },
  primaryPrime: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 17,
  },
  followingPassage: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 14,
    fontVariant: ['tabular-nums'],
  },
  unavailable: {
    fontFamily: 'Inter_500Medium',
    fontSize: 11,
    lineHeight: 14,
  },
});
