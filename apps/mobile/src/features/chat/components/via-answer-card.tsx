import type { JourneyDestination } from '@via/contract';
import { router } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';

import { GlassCard } from '@/components/glass-card';
import { SectionEyebrow } from '@/components/section-eyebrow';
import { SymbolIcon } from '@/components/symbol-icon';
import { ViaAnswerActions } from '@/features/chat/components/via-answer-actions';
import { ViaAnswerSkeleton } from '@/features/chat/components/via-answer-skeleton';
import { ViaRichText } from '@/features/chat/components/via-rich-text';
import { useViaChatContext } from '@/features/chat/hooks/use-via-chat-context';
import { latestAnswerText } from '@/features/chat/model/latest-answer-text';
import { latestItinerary } from '@/features/chat/model/latest-itinerary';
import { useMap } from '@/features/map/hooks/use-map';
import { useAppTheme } from '@/hooks/use-app-theme';
import { formatTime } from '@/lib/format-time';
import { SHEET_GUTTER } from '@/styles/metrics';

/**
 * Via's inline answer inside the search sheet: the reply streams in with line
 * badges and underlined places, then offers "Y aller" and "Répondre".
 */
export function ViaAnswerCard() {
  const { colors } = useAppTheme();
  const { error, itinerary: streamedItinerary, messages, status } = useViaChatContext();
  const { startViaJourney, stationRoutes } = useMap();

  if (messages.length === 0) return null;

  const busy = status === 'submitted' || status === 'streaming';
  const text = latestAnswerText(messages);
  const itinerary = streamedItinerary ?? latestItinerary(messages);
  const journey = itinerary?.response.journeys[0];
  const destination = itinerary?.destination;
  const answerRoutes = [
    ...stationRoutes,
    ...(journey?.sections.flatMap(({ route }) => (route ? [route] : [])) ?? []),
  ];

  const onTime =
    journey &&
    itinerary?.datetimeRepresents === 'arrival' &&
    itinerary.requestedAt &&
    new Date(journey.arrivalAt) <= new Date(itinerary.requestedAt);

  const showItinerary = () => {
    if (!destination || !itinerary) return;
    const coordinate = { latitude: destination.latitude, longitude: destination.longitude };
    const journeyDestination: JourneyDestination =
      destination.kind === 'station'
        ? { kind: 'station', id: destination.id, name: destination.name, coordinate }
        : {
            kind: 'address',
            id: destination.id,
            name: destination.name,
            context: destination.context ?? '',
            coordinate,
          };
    startViaJourney(journeyDestination, itinerary.response);
  };

  return (
    <GlassCard style={styles.card}>
      <View style={styles.eyebrow}>
        <SymbolIcon color={colors.primary} name="sparkles" size={13} />
        <SectionEyebrow label="VIA" />
      </View>

      {text.length > 0 ? (
        <ViaRichText routes={answerRoutes} streaming={busy} text={text} />
      ) : null}
      {busy ? <ViaAnswerSkeleton /> : null}

      {!busy && journey ? (
        <Text style={[styles.arrival, { color: colors.primary }]}>
          {`Arrivée ${formatTime(journey.arrivalAt).replace(':', ' h ')}${onTime ? ', dans les temps.' : '.'}`}
        </Text>
      ) : null}
      {!busy && journey?.warnings?.length ? (
        <Text style={[styles.warning, { color: colors.muted }]}>
          {journey.warnings.join(' ')}
        </Text>
      ) : null}
      {!busy && error && text.length === 0 ? (
        <Text style={[styles.warning, { color: colors.muted }]}>
          Via est momentanément indisponible. Réessaie dans un instant.
        </Text>
      ) : null}

      {!busy && text.length > 0 ? (
        <ViaAnswerActions
          onGo={destination && journey ? showItinerary : undefined}
          onReply={() => router.push('/chat')}
        />
      ) : null}
    </GlassCard>
  );
}

const styles = StyleSheet.create({
  card: {
    marginHorizontal: SHEET_GUTTER,
    marginTop: 12,
    marginBottom: 12,
  },
  eyebrow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  arrival: { fontFamily: 'Archivo_700Bold', fontSize: 19, lineHeight: 26 },
  warning: { fontFamily: 'Inter_400Regular', fontSize: 14, lineHeight: 20 },
});
