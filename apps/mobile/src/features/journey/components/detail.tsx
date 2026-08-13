import type { Journey, JourneyDestination } from '@via/contract';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { JourneyDetailFooter } from '@/features/journey/components/detail-footer';
import { JourneyDurationHero } from '@/features/journey/components/duration-hero';
import { JourneyLegStrip } from '@/features/journey/components/leg-strip';
import { JourneyTimeline } from '@/features/journey/components/timeline';
import { JourneyVariantSelector } from '@/features/journey/components/variant-selector';
import { journeyMinutes } from '@/features/journey/model/minutes';
import { useAppTheme } from '@/hooks/use-app-theme';
import { useNow } from '@/hooks/use-now';
import { SHEET_GUTTER } from '@/styles/metrics';

type JourneyDetailProps = {
  destination: JourneyDestination;
  journeys: Journey[];
  selectedIndex: number;
  onBack: () => void;
  onSelectVariant: (index: number) => void;
};

export function JourneyDetail({ destination, journeys, selectedIndex, onBack, onSelectVariant }: JourneyDetailProps) {
  const { colors } = useAppTheme();
  const now = useNow();
  const journey = journeys[selectedIndex] ?? journeys[0];
  if (!journey) return null;
  const duration = journeyMinutes(journey.durationSeconds);
  const leaveIn = Math.max(0, Math.round((Date.parse(journey.departureAt) - now.getTime()) / 60_000));
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Pressable accessibilityLabel="Retour aux itinéraires" accessibilityRole="button" onPress={onBack} style={styles.back}>
          <SymbolIcon color={colors.ink} name="chevron.left" size={19} />
        </Pressable>
        <View style={styles.heading}>
          <Text style={[styles.eyebrow, { color: colors.primary }]}>ITINÉRAIRE · DÉTAIL</Text>
          <Text numberOfLines={1} selectable style={[styles.destination, { color: colors.ink }]}>{destination.name}</Text>
        </View>
      </View>
      <JourneyVariantSelector journeys={journeys} onSelect={onSelectVariant} selectedIndex={selectedIndex} />
      <ScrollView contentContainerStyle={styles.content} contentInsetAdjustmentBehavior="automatic" showsVerticalScrollIndicator={false} style={styles.scroll}>
        <View style={styles.hero}>
          <JourneyDurationHero minutes={duration} />
          <Text style={[styles.leave, { color: colors.ink }]}>
            {leaveIn > 0 ? `Pars d’ici dans ${leaveIn} min` : 'Pars maintenant'}
          </Text>
        </View>
        <View style={styles.strip}>
          <JourneyLegStrip journey={journey} />
        </View>
        {journey.status === 'theoretical' ? <Text style={[styles.notice, { color: colors.muted }]}>Horaires théoriques · le détail du tracé est indicatif</Text> : null}
        <JourneyTimeline journey={journey} />
      </ScrollView>
      <JourneyDetailFooter destinationName={destination.name} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, gap: 14 },
  header: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: SHEET_GUTTER, paddingTop: 6 },
  back: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center' },
  heading: { flex: 1, gap: 2 },
  eyebrow: { fontFamily: 'Inter_600SemiBold', fontSize: 10, letterSpacing: 1.1 },
  destination: { fontFamily: 'Archivo_800ExtraBold', fontSize: 22, lineHeight: 26 },
  scroll: { flex: 1 },
  content: { gap: 18, paddingHorizontal: SHEET_GUTTER, paddingBottom: 16 },
  hero: { flexDirection: 'row', alignItems: 'baseline', justifyContent: 'space-between', gap: 12 },
  leave: { fontFamily: 'Inter_600SemiBold', fontSize: 14, fontVariant: ['tabular-nums'] },
  strip: { flexDirection: 'row' },
  notice: { fontFamily: 'Inter_400Regular', fontSize: 12, lineHeight: 16 },
});
