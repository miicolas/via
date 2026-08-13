import type { Journey, JourneyDestination } from '@via/contract';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';
import { JourneyStep } from '@/features/home-map/components/journey-step';
import { JourneyVariantSelector } from '@/features/home-map/components/journey-variant-selector';
import { useNow } from '@/hooks/use-now';

type JourneyDetailProps = {
  destination: JourneyDestination;
  journeys: Journey[];
  selectedIndex: number;
  onBack: () => void;
  onSelectVariant: (index: number) => void;
};

export function JourneyDetail({ destination, journeys, selectedIndex, onBack, onSelectVariant }: JourneyDetailProps) {
  const { colors } = useHomeMapTheme();
  const now = useNow();
  const journey = journeys[selectedIndex] ?? journeys[0];
  if (!journey) return null;
  const duration = Math.max(1, Math.round(journey.durationSeconds / 60));
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
      <ScrollView contentContainerStyle={styles.content} contentInsetAdjustmentBehavior="automatic" showsVerticalScrollIndicator={false}>
        <View style={[styles.summary, { backgroundColor: colors.accentSoft, borderColor: colors.line }]}>
          <View>
            <Text style={[styles.big, { color: colors.ink }]}>{duration} min</Text>
            <Text style={[styles.summaryCopy, { color: colors.muted }]}>
              {leaveIn > 0 ? `Départ dans ${leaveIn} min` : 'Départ maintenant'}
            </Text>
          </View>
          <Text style={[styles.times, { color: colors.primary }]}>
            {formatTime(journey.departureAt)} → {formatTime(journey.arrivalAt)}
          </Text>
        </View>
        {journey.status === 'theoretical' ? <Text style={[styles.notice, { color: colors.muted }]}>Horaires théoriques · le détail du tracé est indicatif</Text> : null}
        <View style={styles.steps}>
          {journey.sections.map((section, index) => <JourneyStep key={`${journey.id}:${index}`} last={index === journey.sections.length - 1} section={section} />)}
        </View>
      </ScrollView>
    </View>
  );
}

function formatTime(value: string) {
  return new Intl.DateTimeFormat('fr-FR', { hour: '2-digit', minute: '2-digit' }).format(new Date(value));
}

const styles = StyleSheet.create({
  container: { flex: 1, gap: 14 },
  header: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 20, paddingTop: 6 },
  back: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center' },
  heading: { flex: 1, gap: 2 },
  eyebrow: { fontFamily: 'Inter_700Bold', fontSize: 10, letterSpacing: 1.1 },
  destination: { fontFamily: 'Archivo_800ExtraBold', fontSize: 22, lineHeight: 26 },
  content: { gap: 18, paddingHorizontal: 20, paddingBottom: 32 },
  summary: { flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-between', gap: 12, padding: 16, borderCurve: 'continuous', borderRadius: 22, borderWidth: StyleSheet.hairlineWidth },
  big: { fontFamily: 'Archivo_800ExtraBold', fontSize: 32, lineHeight: 36, fontVariant: ['tabular-nums'] },
  summaryCopy: { fontFamily: 'Inter_400Regular', fontSize: 13 },
  times: { fontFamily: 'Inter_700Bold', fontSize: 14, fontVariant: ['tabular-nums'] },
  notice: { fontFamily: 'Inter_400Regular', fontSize: 12, lineHeight: 16 },
  steps: { paddingTop: 2 },
});
