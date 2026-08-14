import type { NaturalJourneyResponse } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

import { Button } from '@/components/button';
import { FadingScrollView } from '@/components/fading-scroll-view';
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
      <FadingScrollView contentContainerStyle={styles.loading} showsVerticalScrollIndicator={false}>
        <SectionEyebrow label="VIA PRÉPARE TON TRAJET" />
        <JourneyResultsSkeleton />
      </FadingScrollView>
    );
  }

  return (
    <FadingScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
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
                <Button
                  fullWidth
                  key={value}
                  label={value === 'arrival' ? 'Arriver à cette heure' : 'Partir à cette heure'}
                  onPress={() => onResolve({ target: 'time', value })}
                  size="large"
                  tint={colors.primary}
                  variant="prominent"
                />
              ))}
            </View>
          ) : null}
          {field.candidates.length === 0 && field.target !== 'time' ? (
            <Text style={[styles.hint, { color: colors.muted }]}>Précise ce lieu dans la recherche.</Text>
          ) : null}
        </View>
      ))}
    </FadingScrollView>
  );
}

const styles = StyleSheet.create({
  loading: { gap: 16, paddingHorizontal: SHEET_GUTTER, paddingVertical: 12 },
  content: { gap: 20, paddingHorizontal: SHEET_GUTTER, paddingTop: 10, paddingBottom: 36 },
  field: { gap: 8 },
  question: { fontFamily: 'Archivo_700Bold', fontSize: 22, lineHeight: 27 },
  actions: { gap: 10, paddingTop: 4 },
  hint: { fontFamily: 'Inter_400Regular', fontSize: 15, lineHeight: 20 },
});
