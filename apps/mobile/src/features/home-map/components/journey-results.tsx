import type { JourneyDestination, JourneysResponse } from '@via/contract';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { JourneyAlternativeRow } from '@/features/home-map/components/journey-alternative-row';
import { JourneyCard } from '@/features/home-map/components/journey-card';
import { HomeUnavailableState } from '@/features/home-map/components/unavailable-state';
import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';
import { formatDistance } from '@/features/home-map/model/format-distance';

type JourneyResultsProps = {
  destination: JourneyDestination;
  distanceMeters?: number;
  response?: JourneysResponse;
  loading: boolean;
  onRetry: () => void;
  onSelect: (index: number) => void;
};

export function JourneyResults({
  destination,
  distanceMeters,
  response,
  loading,
  onRetry,
  onSelect,
}: JourneyResultsProps) {
  const { colors } = useHomeMapTheme();

  if (loading) {
    return (
      <HomeUnavailableState
        animation={{ effect: { type: 'pulse', wholeSymbol: true }, repeating: true }}
        description="Via cherche le meilleur trajet depuis votre position."
        icon="arrow.triangle.2.circlepath"
        title="Calcul de l’itinéraire…"
      />
    );
  }
  if (!response || response.status === 'unavailable') {
    return (
      <HomeUnavailableState
        actionLabel="Réessayer"
        animation={{ effect: { type: 'pulse' }, repeating: true }}
        description="Le calcul local et le service d’itinéraire sont momentanément indisponibles."
        icon="wifi.exclamationmark"
        onAction={onRetry}
        title="Itinéraire indisponible"
      />
    );
  }
  if (response.journeys.length === 0 || response.status === 'no-route') {
    return (
      <HomeUnavailableState
        actionLabel="Rechercher ailleurs"
        animation="bounce"
        description="Aucun trajet disponible maintenant pour cette destination."
        icon="map"
        onAction={onRetry}
        replayIntervalMs={2800}
        title="Aucun itinéraire"
      />
    );
  }

  const [recommended, ...alternatives] = response.journeys;

  return (
    <ScrollView
      contentContainerStyle={styles.content}
      contentInsetAdjustmentBehavior="automatic"
      showsVerticalScrollIndicator={false}>
      <View style={styles.heading}>
        <Text style={[styles.eyebrow, { color: colors.muted }]}>ITINÉRAIRES</Text>
        <Text numberOfLines={1} selectable style={[styles.destination, { color: colors.muted }]}>
          {destination.name}{distanceMeters !== undefined ? ` · ${formatDistance(distanceMeters)}` : ''}
        </Text>
      </View>

      <JourneyCard journey={recommended} onPress={() => onSelect(0)} />

      {alternatives.length > 0 ? (
        <View style={styles.alternatives}>
          <Text style={[styles.eyebrow, { color: colors.muted }]}>AUTRES ITINÉRAIRES</Text>
          <View style={styles.alternativeRows}>
            {alternatives.map((journey, index) => (
              <JourneyAlternativeRow
                journey={journey}
                key={journey.id}
                onPress={() => onSelect(index + 1)}
              />
            ))}
          </View>
        </View>
      ) : null}

      <Pressable
        accessibilityRole="button"
        onPress={onRetry}
        style={({ pressed }) => [
          styles.askVia,
          { borderBottomColor: colors.line },
          pressed && styles.pressed,
        ]}>
        <View style={styles.askViaLabel}>
          <SymbolIcon color={colors.primary} name="sparkles" size={15} />
          <Text style={[styles.askViaText, { color: colors.primary }]}>Demander autrement à Via</Text>
        </View>
        <SymbolIcon color={colors.primary} name="chevron.right" size={15} />
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: {
    gap: 20,
    paddingHorizontal: 24,
    paddingTop: 8,
    paddingBottom: 36,
  },
  heading: {
    minWidth: 0,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 16,
  },
  eyebrow: {
    fontFamily: 'Inter_700Bold',
    fontSize: 11,
    lineHeight: 15,
    letterSpacing: 1.5,
  },
  destination: {
    minWidth: 0,
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    lineHeight: 19,
    textAlign: 'right',
  },
  alternatives: { gap: 12, paddingTop: 2 },
  alternativeRows: { marginHorizontal: -24, paddingHorizontal: 24 },
  askVia: {
    minHeight: 64,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  askViaLabel: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  askViaText: { fontFamily: 'Inter_500Medium', fontSize: 17, lineHeight: 22 },
  pressed: { opacity: 0.55 },
});
