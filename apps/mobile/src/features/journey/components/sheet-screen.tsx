import { StyleSheet, View } from 'react-native';

import { JourneyDetail } from '@/features/journey/components/detail';
import { JourneyResults } from '@/features/journey/components/results';
import { JourneySearchHeader } from '@/features/journey/components/search-header';
import { NaturalJourneyStatus } from '@/features/journey/components/natural-journey-status';
import { useViaChatContext } from '@/features/chat/hooks/use-via-chat-context';
import { useMap } from '@/features/map/hooks/use-map';

export function JourneySheetScreen() {
  const {
    cancelJourney,
    closeJourneyDetail,
    journey,
    journeyDestination,
    journeyDistanceMeters,
    naturalJourney,
    openJourneyDetail,
    retryJourney,
    resolveNaturalJourney,
    searchQuery,
    screen,
    selectedJourneyIndex,
  } = useMap();
  const viaChat = useViaChatContext();
  const cancelSearch = () => {
    viaChat.reset();
    cancelJourney();
  };

  if (naturalJourney.status === 'interpreting' || naturalJourney.status === 'needs_clarification') {
    return (
      <View style={styles.container}>
        <JourneySearchHeader destination={searchQuery} onCancel={cancelSearch} />
        <NaturalJourneyStatus
          clarification={
            naturalJourney.status === 'needs_clarification' ? naturalJourney.response : undefined
          }
          onResolve={resolveNaturalJourney}
        />
      </View>
    );
  }

  if (!journeyDestination) return null;
  const showingDetail = screen === 'detail' && journey.status === 'ready';
  const naturalAnswer = naturalJourney.status === 'ready' ? naturalJourney.response : undefined;
  const searchLabel = searchQuery.trim().length > 0 ? searchQuery : journeyDestination.name;

  return (
    <View style={styles.container}>
      <JourneySearchHeader
        destination={searchLabel}
        onBack={showingDetail ? closeJourneyDetail : undefined}
        onCancel={cancelSearch}
      />

      {showingDetail ? (
        <JourneyDetail
          destination={journeyDestination}
          journeys={journey.response.journeys}
          selectedIndex={selectedJourneyIndex}
        />
      ) : (
        <JourneyResults
          destination={journeyDestination}
          distanceMeters={journeyDistanceMeters}
          loading={journey.status === 'planning'}
          naturalAnswer={naturalAnswer?.answer}
          naturalNotice={naturalAnswer?.preferenceNotice}
          onRetry={retryJourney}
          onSelect={openJourneyDetail}
          response={journey.status === 'ready' ? journey.response : undefined}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
});
