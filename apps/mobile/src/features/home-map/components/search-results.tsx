import type { NetworkRoute, SearchResult } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

import { AddressResultRow } from '@/features/home-map/components/address-result-row';
import { StationResultRow } from '@/features/home-map/components/station-result-row';
import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';
import type { SearchState } from '@/features/home-map/model/search-state';

const EMPTY_MESSAGE = 'Aucun résultat ne correspond à cette recherche.';
const FAILED_MESSAGE = 'La recherche est momentanément indisponible.';
const BAN_UNAVAILABLE_MESSAGE = 'Adresses momentanément indisponibles';

type HomeSearchResultsProps = {
  onSelect: (result: SearchResult) => void;
  routes: NetworkRoute[];
  search: SearchState;
};

export function HomeSearchResults({ onSelect, routes, search }: HomeSearchResultsProps) {
  const { colors } = useHomeMapTheme();

  if (search.status === 'error' || (search.status === 'ready' && search.results.length === 0)) {
    return (
      <View style={styles.empty}>
        <Text style={[styles.emptyText, { color: colors.muted }]}>
          {search.status === 'error' ? FAILED_MESSAGE : EMPTY_MESSAGE}
        </Text>
      </View>
    );
  }

  return (
    <View style={styles.content}>
      {search.results.map((result) =>
        result.kind === 'station' ? (
          <StationResultRow
            key={`station:${result.id}`}
            onPress={() => onSelect(result)}
            result={result}
            routes={routes}
          />
        ) : (
          <AddressResultRow
            key={`address:${result.id}`}
            onPress={() => onSelect(result)}
            result={result}
          />
        )
      )}
      {search.banUnavailable ? (
        <Text style={[styles.notice, { color: colors.muted }]}>{BAN_UNAVAILABLE_MESSAGE}</Text>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  content: { paddingHorizontal: 20, paddingBottom: 24 },
  notice: {
    paddingVertical: 12,
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    textAlign: 'center',
  },
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
  emptyText: {
    fontFamily: 'Inter_400Regular',
    fontSize: 16,
    textAlign: 'center',
  },
});
