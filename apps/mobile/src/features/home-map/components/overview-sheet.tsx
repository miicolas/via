import { Linking, StyleSheet, View } from 'react-native';

import { CollapsibleReveal } from '@/components/collapsible-reveal';
import { HomeSearchField } from '@/features/home-map/components/search-field';
import { HomeSearchResults } from '@/features/home-map/components/search-results';
import { SheetLoadingSkeleton } from '@/features/home-map/components/sheet-loading-skeleton';
import { Shortcuts } from '@/features/home-map/components/shortcuts';
import { HomeStationSection } from '@/features/home-map/components/station-section';
import { HomeUnavailableState } from '@/features/home-map/components/unavailable-state';
import { useHomeMap } from '@/features/home-map/hooks/use-map';
import { useSheetDetentProgress } from '@/features/home-map/hooks/use-sheet-detent-progress';
import {
  MAP_OVERVIEW_SHEET_COLLAPSED_DETENT_INDEX,
  MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
  MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
} from '@/features/home-map/model/overview-sheet';
import { walkingMinutes } from '@/features/home-map/model/walking-time';

const SHORTCUTS_SPACING = 8;

export function HomeOverviewSheet() {
  const {
    activeRoutes,
    activeStation,
    isSearchActive,
    networkState,
    overviewDetentIndex,
    refreshLocation,
    retryNetwork,
    search,
    selectResult,
    setOverviewDetentIndex,
    setSearchQuery,
    userLocation,
  } = useHomeMap();
  const shortcutsProgress = useSheetDetentProgress(
    MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
    MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX
  );
  const isExpanded = overviewDetentIndex === MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX;
  const showsStation = networkState.status === 'ready' && !isSearchActive;

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <HomeSearchField onChange={setSearchQuery} />

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
        <HomeUnavailableState
          actionLabel="Réessayer"
          description={networkState.message}
          icon="wifi.exclamationmark"
          onAction={retryNetwork}
          title="Réseau indisponible"
        />
      ) : null}

      {networkState.status === 'ready' && isSearchActive ? (
        <HomeSearchResults onSelect={selectResult} routes={networkState.lines} search={search} />
      ) : null}

      {showsStation && activeStation ? (
        <HomeStationSection expanded={isExpanded} routes={activeRoutes} station={activeStation} />
      ) : null}

      {showsStation && !activeStation ? (
        <HomeUnavailableState
          actionLabel={userLocation.status === 'denied' ? 'Ouvrir Réglages' : 'Me localiser'}
          description="La recherche reste disponible pour trouver une station manuellement."
          icon={userLocation.status === 'denied' ? 'location.slash' : 'location.circle'}
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
