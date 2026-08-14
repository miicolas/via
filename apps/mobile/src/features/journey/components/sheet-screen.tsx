import { StyleSheet, View } from 'react-native';

import { JourneyDetail } from '@/features/journey/components/detail';
import { JourneyResults } from '@/features/journey/components/results';
import { JourneySearchHeader } from '@/features/journey/components/search-header';
import { NaturalJourneyStatus } from '@/features/journey/components/natural-journey-status';
import { useViaChatContext } from '@/features/chat/hooks/use-via-chat-context';
import { useAppTheme } from '@/hooks/use-app-theme';
import { useMap } from '@/features/map/hooks/use-map';

type JourneySheetScreenProps = {
  toolbarHeight?: number;
};

export function JourneySheetScreen({ toolbarHeight = 0 }: JourneySheetScreenProps = {}) {
  const { colors } = useAppTheme();
  const {
    cancelJourney,
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
      <View
        style={[styles.container, { backgroundColor: colors.surfaceGlass, paddingTop: toolbarHeight }]}
      >
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
    <View
      style={[styles.container, { backgroundColor: colors.surfaceGlass, paddingTop: toolbarHeight }]}
    >
      <JourneySearchHeader
        destination={searchLabel}
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
