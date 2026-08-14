import { useRouter } from 'expo-router';
import { Linking, StyleSheet, View } from 'react-native';
import type { SearchResult } from '@via/contract';

import { CollapsibleReveal } from '@/components/collapsible-reveal';
import { ViaAnswerCard } from '@/features/chat/components/via-answer-card';
import { useViaChatContext } from '@/features/chat/hooks/use-via-chat-context';
import { SearchField } from '@/features/search/components/field';
import { SearchResults } from '@/features/search/components/results';
import { RecentSearches } from '@/features/search/components/recent-searches';
import type { RecentSearchSnapshot } from '@/features/search/model/recent-searches';
import { SheetLoadingSkeleton } from '@/features/map/components/sheet-loading-skeleton';
import { Shortcuts } from '@/features/map/components/shortcuts';
import { StationSection } from '@/features/departures/components/station-section';
import { UnavailableState } from '@/components/unavailable-state';
import { useMap } from '@/features/map/hooks/use-map';
import { useSheetDetentProgress } from '@/features/map/hooks/use-sheet-detent-progress';
import { isJourneyScreen } from '@/features/map/model/journey-screen';
import {
  MAP_OVERVIEW_SHEET_COLLAPSED_DETENT_INDEX,
  MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
  MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
} from '@/features/map/model/overview-sheet';
import { walkingMinutes } from '@/features/journey/model/walking-time';

const SHORTCUTS_SPACING = 8;

export function OverviewSheet() {
  const router = useRouter();
  const {
    activeStation,
    changeOverviewDetent,
    isNearbyStation,
    journeyDestination,
    networkState,
    overviewDetentIndex,
    refreshLocation,
    retryNetwork,
    recentSearches,
    search,
    searchFocused,
    searchQuery,
    screen,
    selectResult,
    setSearchFocused,
    setSearchQuery,
    userLocation,
  } = useMap();
  const viaChat = useViaChatContext();
  const shortcutsProgress = useSheetDetentProgress(
    MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
    MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX
  );
  const isExpanded = overviewDetentIndex === MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX;
  const isSearchActive = screen === 'search';
  const showsRecentSearches = searchFocused && searchQuery.trim().length === 0;
  const showsOverview =
    networkState.status === 'ready' && !isSearchActive && !journeyDestination;
  const showsStation = showsOverview && isNearbyStation;
  const handleSelectResult = (result: SearchResult | RecentSearchSnapshot) => {
    if (selectResult(result)) router.navigate('/map/journey');
  };
  // Submitting a phrase asks Via inline; the answer card streams into the sheet.
  const askVia = () => {
    const phrase = searchQuery.trim();
    if (phrase) viaChat.ask(phrase);
  };
  const viaActive = isSearchActive && viaChat.messages.length > 0;

  if (isJourneyScreen(screen)) return null;

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <SearchField
          onChange={setSearchQuery}
          onFocusChange={setSearchFocused}
          onSubmit={askVia}
          value={searchQuery}
        />

        {showsStation ? (
          <CollapsibleReveal progress={shortcutsProgress} spacing={SHORTCUTS_SPACING}>
            <Shortcuts
              onClose={() => changeOverviewDetent(MAP_OVERVIEW_SHEET_COLLAPSED_DETENT_INDEX)}
              onLocate={() => void refreshLocation()}
              walkingMinutes={walkingMinutes(activeStation?.distanceMeters)}
            />
          </CollapsibleReveal>
        ) : null}
      </View>

      {networkState.status === 'loading' && !showsRecentSearches ? <SheetLoadingSkeleton /> : null}

      {networkState.status === 'error' && !showsRecentSearches ? (
        <UnavailableState
          actionLabel="Réessayer"
          animation={{ effect: { type: 'pulse' }, repeating: true }}
          description={networkState.message}
          icon="wifi.exclamationmark"
          onAction={retryNetwork}
          title="Réseau indisponible"
        />
      ) : null}

      {showsRecentSearches ? (
        <RecentSearches
          entries={recentSearches.entries}
          onRemove={recentSearches.remove}
          onSelect={handleSelectResult}
        />
      ) : null}

      {viaActive ? (
        <>
          <ViaAnswerCard />
          <RecentSearches
            entries={recentSearches.entries}
            onRemove={recentSearches.remove}
            onSelect={handleSelectResult}
          />
        </>
      ) : null}

      {networkState.status === 'ready' && !viaActive && isSearchActive && searchQuery.trim().length > 0 ? (
        <SearchResults onSelect={handleSelectResult} search={search} />
      ) : null}

      {showsStation && activeStation ? (
        <StationSection expanded={isExpanded} station={activeStation} />
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
