import type { NetworkStation } from '@via/contract';
import { SymbolView } from 'expo-symbols';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { HomeMapTheme } from '@/features/home-map/theme';

type HomeSearchResultsProps = {
  onSelect: (stationId: string) => void;
  stations: NetworkStation[];
};

export function HomeSearchResults({ onSelect, stations }: HomeSearchResultsProps) {
  if (stations.length === 0) {
    return (
      <View style={styles.empty}>
        <Text style={styles.emptyText}>Aucune station ne correspond à cette recherche.</Text>
      </View>
    );
  }

  return (
    <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
      {stations.map((station) => {
        const lineCount = Object.keys(station.positions).length;
        return (
          <Pressable
            accessibilityRole="button"
            key={station.id}
            onPress={() => onSelect(station.id)}
            style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
            <SymbolView name="tram.circle.fill" size={30} tintColor={HomeMapTheme.primary} />
            <View style={styles.copy}>
              <Text style={styles.stationName}>{station.name}</Text>
              <Text style={styles.lineCount}>{`${lineCount} ligne${lineCount > 1 ? 's' : ''}`}</Text>
            </View>
          </Pressable>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: { paddingHorizontal: 20, paddingBottom: 24 },
  row: {
    minHeight: 64,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#161A181F',
  },
  copy: { flex: 1, gap: 2 },
  stationName: {
    color: HomeMapTheme.ink,
    fontFamily: 'Inter_600SemiBold',
    fontSize: 17,
    lineHeight: 21,
  },
  lineCount: {
    color: HomeMapTheme.muted,
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
  },
  pressed: { opacity: 0.5 },
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
  emptyText: {
    color: HomeMapTheme.muted,
    fontFamily: 'Inter_400Regular',
    fontSize: 16,
    textAlign: 'center',
  },
});
