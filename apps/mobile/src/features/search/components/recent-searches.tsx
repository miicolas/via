import { Host } from '@expo/ui';
import { RNHostView, SwipeActions } from '@expo/ui/swift-ui';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/button';
import { SectionEyebrow } from '@/components/section-eyebrow';
import { RecentSearchRow } from '@/features/search/components/recent-search-row';
import { recentSearchKey } from '@/features/search/model/recent-search-key';
import type { RecentSearchSnapshot } from '@/features/search/model/recent-searches';
import { useAppTheme } from '@/hooks/use-app-theme';

type RecentSearchesProps = {
  entries: RecentSearchSnapshot[];
  onRemove: (entry: RecentSearchSnapshot) => void;
  onSelect: (entry: RecentSearchSnapshot) => void;
};

export function RecentSearches({ entries, onRemove, onSelect }: RecentSearchesProps) {
  const { colorScheme } = useAppTheme();

  if (entries.length === 0) return null;

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <SectionEyebrow label="RÉCENTS" />
      </View>
      {entries.map((entry) => (
        <Host
          colorScheme={colorScheme}
          // Each row is already positioned inside the RN sheet. A second
          // SwiftUI keyboard inset makes the matchContents row remeasure at
          // the wrong origin when the TextField gains focus.
          ignoreSafeArea="all"
          key={recentSearchKey(entry)}
          matchContents={{ vertical: true }}
          style={styles.host}>
          <SwipeActions>
            <RNHostView matchContents>
              <RecentSearchRow onPress={() => onSelect(entry)} result={entry} />
            </RNHostView>
            <SwipeActions.Actions allowsFullSwipe edge="trailing">
              <Button
                embedded
                label="Supprimer"
                onPress={() => onRemove(entry)}
                role="destructive"
                variant="plain"
              />
            </SwipeActions.Actions>
          </SwipeActions>
        </Host>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { paddingBottom: 24 },
  header: { paddingHorizontal: 20, paddingTop: 14, paddingBottom: 8 },
  host: { width: '100%' },
});
