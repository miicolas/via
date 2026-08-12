import type { NativeStackNavigationProp } from 'expo-router';
import { useNavigation, useRouter } from 'expo-router';
import { useEffect } from 'react';
import { Linking, StyleSheet, View } from 'react-native';

import { HomeSearchField } from '@/features/home-map/components/search-field';
import { HomeSearchResults } from '@/features/home-map/components/search-results';
import { SheetLoadingSkeleton } from '@/features/home-map/components/sheet-loading-skeleton';
import { Shortcuts } from '@/features/home-map/components/shortcuts';
import { HomeStationSection } from '@/features/home-map/components/station-section';
import { HomeUnavailableState } from '@/features/home-map/components/unavailable-state';
import { useHomeMap } from '@/features/home-map/hooks/use-map';
import { MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX } from '@/features/home-map/model/overview-sheet';

type MapStackParamList = {
  index: undefined;
  overview: undefined;
};

export function HomeOverviewSheet() {
  const navigation = useNavigation<NativeStackNavigationProp<MapStackParamList, 'overview'>>();
  const router = useRouter();
  const {
    activeRoutes,
    activeStation,
    isSearchActive,
    networkState,
    refreshLocation,
    retryNetwork,
    search,
    selectResult,
    setOverviewDetentIndex,
    setSearchQuery,
    userLocation,
  } = useHomeMap();

  useEffect(() => {
    setOverviewDetentIndex(MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX);
    return navigation.addListener('sheetDetentChange', ({ data }) => {
      if (data.stable) setOverviewDetentIndex(data.index);
    });
  }, [navigation, setOverviewDetentIndex]);

  const close = () => {
    if (router.canDismiss()) router.dismiss();
    else router.replace('/map');
  };
  const walkingMinutes = activeStation?.distanceMeters
    ? Math.max(1, Math.round(activeStation.distanceMeters / 80))
    : undefined;

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <HomeSearchField onChange={setSearchQuery} />

        {networkState.status === 'ready' && !isSearchActive ? (
          <Shortcuts
            onClose={close}
            onLocate={() => void refreshLocation()}
            walkingMinutes={walkingMinutes}
          />
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

      {networkState.status === 'ready' && !isSearchActive && activeStation ? (
        <HomeStationSection routes={activeRoutes} station={activeStation} />
      ) : null}

      {networkState.status === 'ready' && !isSearchActive && !activeStation ? (
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
  header: { gap: 10, paddingTop: 12 },
});
