import type { JourneyDestination, JourneysResponse } from '@via/contract';
import { StyleSheet, View } from 'react-native';
import Animated, { Easing, Keyframe, useReducedMotion } from 'react-native-reanimated';

import { FadingScrollView } from '@/components/fading-scroll-view';
import { SectionEyebrow } from '@/components/section-eyebrow';
import { UnavailableState } from '@/components/unavailable-state';
import { AskViaRow } from '@/features/journey/components/ask-via-row';
import { JourneyAlternativeRow } from '@/features/journey/components/alternative-row';
import { JourneyCard } from '@/features/journey/components/card';
import { JourneyResultsHeading } from '@/features/journey/components/results-heading';
import { JourneyResultsSkeleton } from '@/features/journey/components/results-skeleton';
import { ViaAnswerCard } from '@/features/journey/components/via-answer-card';
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
  naturalAnswer?: string;
  naturalNotice?: string;
};

/** The computed answer: one recommended journey, then the alternatives it beat. */
export function JourneyResults({
  destination,
  distanceMeters,
  response,
  loading,
  onRetry,
  onSelect,
  naturalAnswer,
  naturalNotice,
}: JourneyResultsProps) {
  const reduceMotion = useReducedMotion();
  const distance = distanceMeters === undefined ? '' : ` · ${formatDistance(distanceMeters)}`;
  const heading = <JourneyResultsHeading detail={`${destination.name}${distance}`} />;

  if (loading) {
    return (
      <FadingScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {heading}
        <JourneyResultsSkeleton />
      </FadingScrollView>
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
    <FadingScrollView
      contentContainerStyle={styles.content}
      contentInsetAdjustmentBehavior="automatic"
      showsVerticalScrollIndicator={false}>
      <Animated.View entering={resultEntry(reduceMotion, 0)}>{heading}</Animated.View>

      {naturalAnswer ? (
        <Animated.View entering={resultEntry(reduceMotion, 30)} style={styles.gutter}>
          <ViaAnswerCard answer={naturalAnswer} notice={naturalNotice} />
        </Animated.View>
      ) : null}

      <Animated.View entering={resultEntry(reduceMotion, 40)} style={styles.gutter}>
        <JourneyCard
          journey={recommended}
          onPress={() => onSelect(0)}
          reason={recommendationReason(response.journeys)}
        />
      </Animated.View>

      <View>
        {alternatives.length > 0 ? (
          <Animated.View entering={resultEntry(reduceMotion, 80)} style={styles.listHeader}>
            <SectionEyebrow label="VOIR LES AUTRES ITINÉRAIRES" />
          </Animated.View>
        ) : null}
        {alternatives.map((journey, index) => (
          <Animated.View
            entering={resultEntry(reduceMotion, 100 + Math.min(index, 3) * 40)}
            key={journey.id}>
            <JourneyAlternativeRow journey={journey} onPress={() => onSelect(index + 1)} />
          </Animated.View>
        ))}
        <Animated.View entering={resultEntry(reduceMotion, 140)} style={styles.gutter}>
          <AskViaRow />
        </Animated.View>
      </View>
    </FadingScrollView>
  );
}

function resultEntry(reduceMotion: boolean, delayMs: number) {
  if (reduceMotion) return undefined;

  return new Keyframe({
    0: { transform: [{ translateY: 8 }] },
    100: {
      transform: [{ translateY: 0 }],
      easing: Easing.bezier(0.23, 1, 0.32, 1),
    },
  })
    .duration(220)
    .delay(delayMs);
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
