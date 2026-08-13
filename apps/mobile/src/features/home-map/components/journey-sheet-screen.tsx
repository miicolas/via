import { StyleSheet, View } from 'react-native';

import { JourneyDetail } from '@/features/home-map/components/journey-detail';
import { JourneyResults } from '@/features/home-map/components/journey-results';
import { JourneySearchHeader } from '@/features/home-map/components/journey-search-header';
import { useHomeMap } from '@/features/home-map/hooks/use-map';

export function JourneySheetScreen() {
  const {
    cancelJourney,
    closeJourneyDetail,
    flow,
    journey,
    journeyDestination,
    journeyDistanceMeters,
    openJourneyDetail,
    retryJourney,
    selectedJourneyIndex,
  } = useHomeMap();

  if (!journeyDestination) return null;

  return (
    <View style={styles.container}>
      <JourneySearchHeader destination={journeyDestination.name} onCancel={cancelJourney} />

      {flow.screen === 'detail' && journey.status === 'ready' ? (
        <JourneyDetail
          destination={journeyDestination}
          journeys={journey.response.journeys}
          onBack={closeJourneyDetail}
          onSelectVariant={openJourneyDetail}
          selectedIndex={selectedJourneyIndex}
        />
      ) : (
        <JourneyResults
          destination={journeyDestination}
          distanceMeters={journeyDistanceMeters}
          loading={journey.status === 'planning'}
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
