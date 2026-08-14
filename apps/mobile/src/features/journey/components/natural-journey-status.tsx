import type { NaturalJourneyResponse } from '@via/contract';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { SectionEyebrow } from '@/components/section-eyebrow';
import { JourneyResultsSkeleton } from '@/features/journey/components/results-skeleton';
import type { NaturalJourneyChoice } from '@/features/journey/model/clarification-choice';
import { SearchResultRow } from '@/features/search/components/result-row';
import { useAppTheme } from '@/hooks/use-app-theme';
import { SHEET_GUTTER } from '@/styles/metrics';

type Clarification = Extract<NaturalJourneyResponse, { status: 'needs_clarification' }>;

type Props = {
  clarification?: Clarification;
  onResolve: (choice: NaturalJourneyChoice) => void;
};

export function NaturalJourneyStatus({ clarification, onResolve }: Props) {
  const { colors } = useAppTheme();

  if (!clarification) {
    return (
      <ScrollView contentContainerStyle={styles.loading} showsVerticalScrollIndicator={false}>
        <SectionEyebrow label="VIA PRÉPARE TON TRAJET" />
        <JourneyResultsSkeleton />
      </ScrollView>
    );
  }

  return (
    <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
      <SectionEyebrow label="UNE PRÉCISION" />
      {clarification.fields.map((field) => (
        <View key={field.target} style={styles.field}>
          <Text style={[styles.question, { color: colors.ink }]}>{field.question}</Text>
          {field.candidates.map((candidate) => (
            <SearchResultRow
              key={`${field.target}:${candidate.kind}:${candidate.id}`}
              onPress={() =>
                onResolve({ target: field.target as 'origin' | 'destination', result: candidate })
              }
              result={candidate}
            />
          ))}
          {field.target === 'time' ? (
            <View style={styles.actions}>
              {(['arrival', 'departure'] as const).map((value) => (
                <Pressable
                  accessibilityRole="button"
                  key={value}
                  onPress={() => onResolve({ target: 'time', value })}
                  style={({ pressed }) => [
                    styles.action,
                    { backgroundColor: colors.primary },
                    pressed && styles.pressed,
                  ]}>
                  <Text style={[styles.actionText, { color: colors.surface }]}>
                    {value === 'arrival' ? 'Arriver à cette heure' : 'Partir à cette heure'}
                  </Text>
                </Pressable>
              ))}
            </View>
          ) : null}
          {field.candidates.length === 0 && field.target !== 'time' ? (
            <Text style={[styles.hint, { color: colors.muted }]}>Précise ce lieu dans la recherche.</Text>
          ) : null}
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  loading: { gap: 16, paddingHorizontal: SHEET_GUTTER, paddingVertical: 12 },
  content: { gap: 20, paddingHorizontal: SHEET_GUTTER, paddingTop: 10, paddingBottom: 36 },
  field: { gap: 8 },
  question: { fontFamily: 'Archivo_700Bold', fontSize: 22, lineHeight: 27 },
  actions: { gap: 10, paddingTop: 4 },
  action: { minHeight: 48, alignItems: 'center', justifyContent: 'center', borderRadius: 24 },
  actionText: { fontFamily: 'Inter_600SemiBold', fontSize: 15 },
  hint: { fontFamily: 'Inter_400Regular', fontSize: 15, lineHeight: 20 },
  pressed: { opacity: 0.7 },
});
