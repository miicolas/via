import type { JourneyDestination, JourneysResponse } from '@via/contract';
import { ScrollView, StyleSheet, View } from 'react-native';

import { SectionEyebrow } from '@/components/section-eyebrow';
import { UnavailableState } from '@/components/unavailable-state';
import { AskViaRow } from '@/features/journey/components/ask-via-row';
import { JourneyAlternativeRow } from '@/features/journey/components/alternative-row';
import { JourneyCard } from '@/features/journey/components/card';
import { JourneyResultsHeading } from '@/features/journey/components/results-heading';
import { JourneyResultsSkeleton } from '@/features/journey/components/results-skeleton';
import { recommendationReason } from '@/features/journey/model/recommendation-reason';
import { formatDistance } from '@/lib/format-distance';
import { SHEET_GUTTER } from '@/styles/metrics';

type JourneyResultsProps = {
  destination: JourneyDestination;
  distanceMeters?: number;
  response?: JourneysResponse;
  loading: boolean;
  onRetry: () => void;
  onSelect: (index: number) => void;
};

/** The computed answer: one recommended journey, then the alternatives it beat. */
export function JourneyResults({
  destination,
  distanceMeters,
  response,
  loading,
  onRetry,
  onSelect,
}: JourneyResultsProps) {
  const distance = distanceMeters === undefined ? '' : ` · ${formatDistance(distanceMeters)}`;
  const heading = <JourneyResultsHeading detail={`${destination.name}${distance}`} />;

  if (loading) {
    return (
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {heading}
        <JourneyResultsSkeleton />
      </ScrollView>
    );
  }

  if (!response || response.status === 'unavailable') {
    return (
      <UnavailableState
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
      <UnavailableState
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
      {heading}

      <View style={styles.gutter}>
        <JourneyCard
          journey={recommended}
          onPress={() => onSelect(0)}
          reason={recommendationReason(response.journeys)}
        />
      </View>

      <View>
        {alternatives.length > 0 ? (
          <View style={styles.listHeader}>
            <SectionEyebrow label="AUTRES ITINÉRAIRES" />
          </View>
        ) : null}
        {alternatives.map((journey, index) => (
          <JourneyAlternativeRow
            journey={journey}
            key={journey.id}
            onPress={() => onSelect(index + 1)}
          />
        ))}
        <View style={styles.gutter}>
          <AskViaRow onPress={onRetry} />
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: {
    gap: 14,
    paddingTop: 4,
    paddingBottom: 36,
  },
  gutter: { paddingHorizontal: SHEET_GUTTER },
  listHeader: { paddingTop: 16, paddingBottom: 10, paddingHorizontal: SHEET_GUTTER },
});
