import { StyleSheet, View } from 'react-native';

import { SectionEyebrow } from '@/components/section-eyebrow';
import { RecentSearchRow } from '@/features/search/components/recent-search-row';
import { recentSearchKey } from '@/features/search/model/recent-search-key';
import type { RecentSearchSnapshot } from '@/features/search/model/recent-searches';

type RecentSearchesProps = {
  entries: RecentSearchSnapshot[];
  onRemove: (entry: RecentSearchSnapshot) => void;
  onSelect: (entry: RecentSearchSnapshot) => void;
};

/** iOS adds native swipe actions; other targets retain the same recent list and selection. */
export function RecentSearches({ entries, onSelect }: RecentSearchesProps) {
  if (entries.length === 0) return null;

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <SectionEyebrow label="RÉCENTS" />
      </View>
      {entries.map((entry) => (
        <RecentSearchRow
          key={recentSearchKey(entry)}
          onPress={() => onSelect(entry)}
          result={entry}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { paddingBottom: 24 },
  header: { paddingHorizontal: 20, paddingTop: 14, paddingBottom: 8 },
});
