import { Linking, StyleSheet, View } from 'react-native';
import type { SearchResult } from '@via/contract';

import { CollapsibleReveal } from '@/components/collapsible-reveal';
import { SearchField } from '@/features/search/components/field';
import { SearchResults } from '@/features/search/components/results';
import { SheetLoadingSkeleton } from '@/features/map/components/sheet-loading-skeleton';
import { Shortcuts } from '@/features/map/components/shortcuts';
import { StationSection } from '@/features/departures/components/station-section';
import { UnavailableState } from '@/components/unavailable-state';
import { JourneySheetScreen } from '@/features/journey/components/sheet-screen';
import { useMap } from '@/features/map/hooks/use-map';
import { useSheetDetentProgress } from '@/features/map/hooks/use-sheet-detent-progress';
import {
  MAP_OVERVIEW_SHEET_COLLAPSED_DETENT_INDEX,
  MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
  MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
} from '@/features/map/model/overview-sheet';
import { walkingMinutes } from '@/features/journey/model/walking-time';

const SHORTCUTS_SPACING = 8;

export function OverviewSheet() {
  const {
    activeRoutes,
    activeStation,
    flow,
    isSearchActive,
    isNearbyStation,
    journeyDestination,
    networkState,
    overviewDetentIndex,
    refreshLocation,
    retryNetwork,
    search,
    searchQuery,
    selectResult,
    setOverviewDetentIndex,
    setSearchQuery,
    userLocation,
  } = useMap();
  const shortcutsProgress = useSheetDetentProgress(
    MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
    MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX
  );
  const isExpanded = overviewDetentIndex === MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX;
  const showsOverview =
    networkState.status === 'ready' && !isSearchActive && !journeyDestination;
  const showsStation = showsOverview && isNearbyStation;
  const handleSelectResult = (result: SearchResult) => void selectResult(result);

  if (flow.screen === 'planning' || flow.screen === 'results' || flow.screen === 'detail') {
    return <JourneySheetScreen />;
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <SearchField onChange={setSearchQuery} value={searchQuery} />

        {showsStation ? (
          <CollapsibleReveal progress={shortcutsProgress} spacing={SHORTCUTS_SPACING}>
            <Shortcuts
              onClose={() => setOverviewDetentIndex(MAP_OVERVIEW_SHEET_COLLAPSED_DETENT_INDEX)}
              onLocate={() => void refreshLocation()}
              walkingMinutes={walkingMinutes(activeStation?.distanceMeters)}
            />
          </CollapsibleReveal>
        ) : null}
      </View>

      {networkState.status === 'loading' ? <SheetLoadingSkeleton /> : null}

      {networkState.status === 'error' ? (
        <UnavailableState
          actionLabel="Réessayer"
          animation={{ effect: { type: 'pulse' }, repeating: true }}
          description={networkState.message}
          icon="wifi.exclamationmark"
          onAction={retryNetwork}
          title="Réseau indisponible"
        />
      ) : null}

      {networkState.status === 'ready' && isSearchActive ? (
        <SearchResults onSelect={handleSelectResult} routes={networkState.lines} search={search} />
      ) : null}

      {showsStation && activeStation ? (
        <StationSection expanded={isExpanded} routes={activeRoutes} station={activeStation} />
      ) : null}

      {showsOverview && !activeStation ? (
        <UnavailableState
          actionLabel={userLocation.status === 'denied' ? 'Ouvrir Réglages' : 'Me localiser'}
          animation={
            userLocation.status === 'denied'
              ? 'bounce'
              : { effect: { type: 'pulse', wholeSymbol: true }, repeating: true }
          }
          description="La recherche reste disponible pour trouver une station manuellement."
          icon={userLocation.status === 'denied' ? 'location.slash' : 'location.circle'}
          replayIntervalMs={userLocation.status === 'denied' ? 3000 : undefined}
          onAction={
            userLocation.status === 'denied'
              ? () => void Linking.openSettings()
              : () => void refreshLocation()
          }
          title={
            userLocation.status === 'loading'
              ? 'Localisation en cours'
              : 'Aucune station à proximité'
          }
        />
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: { paddingTop: 4 },
});
