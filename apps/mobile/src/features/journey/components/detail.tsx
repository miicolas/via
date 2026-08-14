import type { Journey, JourneyDestination } from '@via/contract';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { JourneyDepartureCountdown } from '@/features/journey/components/departure-countdown';
import { JourneyDetailFooter } from '@/features/journey/components/detail-footer';
import { JourneyDurationHero } from '@/features/journey/components/duration-hero';
import { JourneyLegStrip } from '@/features/journey/components/leg-strip';
import { JourneyTimeline } from '@/features/journey/components/timeline';
import { journeyMinutes } from '@/features/journey/model/minutes';
import { useAppTheme } from '@/hooks/use-app-theme';
import { useNow } from '@/hooks/use-now';
import { SHEET_GUTTER } from '@/styles/metrics';

type JourneyDetailProps = {
  destination: JourneyDestination;
  journeys: Journey[];
  selectedIndex: number;
};

export function JourneyDetail({ destination, journeys, selectedIndex }: JourneyDetailProps) {
  const { colors } = useAppTheme();
  const now = useNow();
  const journey = journeys[selectedIndex] ?? journeys[0];
  if (!journey) return null;
  const duration = journeyMinutes(journey.durationSeconds);
  const leaveIn = Math.max(
    0,
    Math.floor((Date.parse(journey.departureAt) - now.getTime()) / 60_000)
  );
  return (
    <View style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.content}
        contentInsetAdjustmentBehavior="automatic"
        showsVerticalScrollIndicator={false}
        style={styles.scroll}
      >
          <View style={styles.hero}>
            <JourneyDurationHero minutes={duration} />
            <JourneyDepartureCountdown
              minutes={leaveIn}
              realtime={journey.status !== 'theoretical'}
            />
          </View>
          <View style={styles.strip}>
            <JourneyLegStrip journey={journey} />
          </View>
          {journey.status === 'theoretical' ? (
            <Text style={[styles.notice, { color: colors.muted }]}>
              Horaires théoriques · le détail du tracé est indicatif
            </Text>
          ) : null}

        <JourneyTimeline journey={journey} />
      </ScrollView>
      <JourneyDetailFooter destinationName={destination.name} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, gap: 4 },
  scroll: { flex: 1 },
  content: { gap: 12, paddingHorizontal: SHEET_GUTTER, paddingBottom: 16 },
  hero: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 12 },
  strip: { flexDirection: 'row' },
  notice: { fontFamily: 'Inter_400Regular', fontSize: 12, lineHeight: 16 },
});
