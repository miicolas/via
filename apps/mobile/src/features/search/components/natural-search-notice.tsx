import type { NaturalJourneyResponse } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { useAppTheme } from '@/hooks/use-app-theme';
import { SHEET_GUTTER } from '@/styles/metrics';

type ErrorResponse = Exclude<
  NaturalJourneyResponse,
  { status: 'ready' | 'needs_clarification' }
>;

export function NaturalSearchNotice({ response }: { response: ErrorResponse }) {
  const { colors } = useAppTheme();
  return (
    <View style={[styles.card, { backgroundColor: colors.track }]}>
      <SymbolIcon color={colors.primary} name="sparkles" size={15} />
      <View style={styles.copy}>
        <Text style={[styles.message, { color: colors.ink }]}>{response.message}</Text>
        {response.status === 'unsupported' ? (
          <Text style={[styles.examples, { color: colors.muted }]}>Exemples : {response.examples.join(' · ')}</Text>
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    minHeight: 52,
    marginHorizontal: SHEET_GUTTER,
    marginBottom: 10,
    padding: 14,
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 10,
    borderRadius: 18,
    borderCurve: 'continuous',
  },
  copy: { minWidth: 0, flex: 1, gap: 4 },
  message: { fontFamily: 'Inter_500Medium', fontSize: 14, lineHeight: 19 },
  examples: { fontFamily: 'Inter_400Regular', fontSize: 12, lineHeight: 17 },
});
