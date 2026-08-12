import { useRouter } from 'expo-router';
import { GlassView } from 'expo-glass-effect';
import { ActivityIndicator, Linking, StyleSheet, View } from 'react-native';

import { HomeSearchField } from '@/features/home-map/search-field';
import { HomeSearchResults } from '@/features/home-map/search-results';
import { Shortcuts } from '@/features/home-map/shortcuts';
import { HomeStationSection } from '@/features/home-map/station-section';
import { HomeMapTheme } from '@/features/home-map/theme';
import { HomeUnavailableState } from '@/features/home-map/unavailable-state';
import { useHomeMap } from '@/features/home-map/use-map';

export function HomeOverviewSheet() {
  const router = useRouter();
  const {
    activeRoutes,
    activeStation,
    isSearchActive,
    networkState,
    refreshLocation,
    retryNetwork,
    searchResults,
    selectStation,
    setSearchQuery,
    userLocation,
  } = useHomeMap();

  const close = () => {
    if (router.canDismiss()) router.dismiss();
    else router.replace('/map');
  };
  const walkingMinutes = activeStation?.distanceMeters
    ? Math.max(1, Math.round(activeStation.distanceMeters / 80))
    : undefined;

  return (
    <View style={styles.container}>
      <GlassView
        colorScheme="light"
        glassEffectStyle="regular"
        pointerEvents="none"
        style={StyleSheet.absoluteFill}
        tintColor="#F2F0E9B8"
      />

      <HomeSearchField onChange={setSearchQuery} />

      {networkState.status === 'ready' && !isSearchActive ? (
        <Shortcuts
          lineCount={activeRoutes.length}
          onClose={close}
          onLocate={() => void refreshLocation()}
          walkingMinutes={walkingMinutes}
        />
      ) : null}

      {networkState.status === 'loading' ? (
        <View style={styles.loader}>
          <ActivityIndicator color={HomeMapTheme.primary} size="large" />
        </View>
      ) : null}

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
        <HomeSearchResults onSelect={selectStation} stations={searchResults} />
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
  container: { flex: 1, gap: 10, paddingTop: 16, backgroundColor: 'transparent' },
  loader: { flex: 1, alignItems: 'center', justifyContent: 'center' },
});
