import { StyleSheet, View } from 'react-native';

import { JourneyDetail } from '@/features/journey/components/detail';
import { JourneyResults } from '@/features/journey/components/results';
import { JourneySearchHeader } from '@/features/journey/components/search-header';
import { useMap } from '@/features/map/hooks/use-map';

export function JourneySheetScreen() {
  const {
    cancelJourney,
    closeJourneyDetail,
    journey,
    journeyDestination,
    journeyDistanceMeters,
    openJourneyDetail,
    retryJourney,
    screen,
    selectedJourneyIndex,
  } = useMap();

  if (!journeyDestination) return null;

  return (
    <View style={styles.container}>
      <JourneySearchHeader destination={journeyDestination.name} onCancel={cancelJourney} />

      {screen === 'detail' && journey.status === 'ready' ? (
        <JourneyDetail
          destination={journeyDestination}
          journeys={journey.response.journeys}
          onBack={closeJourneyDetail}
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
