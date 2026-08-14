import { usePathname, useRouter } from 'expo-router';
import { StyleSheet, Text } from 'react-native';

import { Button } from '@/components/button';
import { SymbolIcon } from '@/components/symbol-icon';
import { useMap } from '@/features/map/hooks/use-map';
import { useAppTheme } from '@/hooks/use-app-theme';

/** Opens the Via conversation to follow up on the shown journeys. */
export function AskViaRow() {
  const { colors } = useAppTheme();
  const { openChat } = useMap();
  const pathname = usePathname();
  const router = useRouter();
  const openVia = () => {
    openChat();
    if (!pathname.endsWith('/map/journey')) router.navigate('/map/journey');
  };

  return (
    <Button
      contentStyle={styles.row}
      fullWidth
      label="Demander autrement à Via"
      onPress={openVia}
      variant="plain">
      <SymbolIcon color={colors.primary} name="sparkles" size={14} />
      <Text style={[styles.label, { color: colors.ink }]}>Demander autrement à Via</Text>
      <SymbolIcon color={colors.muted} name="chevron.right" size={12} />
    </Button>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingVertical: 16,
  },
  label: {
    minWidth: 0,
    flex: 1,
    fontFamily: 'Inter_500Medium',
    fontSize: 16,
    lineHeight: 20,
    letterSpacing: -0.16,
  },
});
