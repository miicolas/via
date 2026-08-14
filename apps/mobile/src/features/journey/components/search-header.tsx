import { StyleSheet, Text, View } from 'react-native';

import { Button } from '@/components/button';
import { SearchFieldShell } from '@/components/search-field-shell';
import { SymbolIcon } from '@/components/symbol-icon';
import { useAppTheme } from '@/hooks/use-app-theme';

type JourneySearchHeaderProps = {
  destination: string;
  onCancel: () => void;
};

export function JourneySearchHeader({ destination, onCancel }: JourneySearchHeaderProps) {
  const { colors } = useAppTheme();

  return (
    <View style={styles.container}>
      <SearchFieldShell style={styles.search}>
        <Button
          accessibilityHint="Annule la recherche et revient à ta localisation"
          contentStyle={styles.buttonContent}
          embedded
          fullWidth
          label={`Destination ${destination}`}
          onPress={onCancel}
          variant="plain">
          <SymbolIcon color={colors.primary} name="magnifyingglass" size={18} weight="regular" />
          <Text numberOfLines={1} style={[styles.destination, { color: colors.ink }]}>
            {destination}
          </Text>
        </Button>
      </SearchFieldShell>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingTop: 4,
    paddingBottom: 10,
  },
  search: {
    flex: 1,
  },
  buttonContent: {
    minWidth: 0,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  destination: {
    minWidth: 0,
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 16,
    lineHeight: 20,
    letterSpacing: -0.16,
  },
});
