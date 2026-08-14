import { StyleSheet, Text, View } from 'react-native';

import { GlassCard } from '@/components/glass-card';
import { SymbolIcon } from '@/components/symbol-icon';
import { useAppTheme } from '@/hooks/use-app-theme';

type Props = { answer: string; notice?: string };

export function ViaAnswerCard({ answer, notice }: Props) {
  const { colors } = useAppTheme();
  return (
    <GlassCard>
      <View style={styles.label}>
        <SymbolIcon color={colors.primary} name="sparkles" size={14} />
        <Text style={[styles.eyebrow, { color: colors.primary }]}>VIA</Text>
      </View>
      <Text selectable style={[styles.answer, { color: colors.ink }]}>{answer}</Text>
      {notice ? <Text style={[styles.notice, { color: colors.muted }]}>{notice}</Text> : null}
    </GlassCard>
  );
}

const styles = StyleSheet.create({
  label: { flexDirection: 'row', alignItems: 'center', gap: 7 },
  eyebrow: { fontFamily: 'Inter_600SemiBold', fontSize: 12, letterSpacing: 1.2 },
  answer: { fontFamily: 'Archivo_700Bold', fontSize: 20, lineHeight: 27, letterSpacing: -0.3 },
  notice: { fontFamily: 'Inter_400Regular', fontSize: 14, lineHeight: 20 },
});
