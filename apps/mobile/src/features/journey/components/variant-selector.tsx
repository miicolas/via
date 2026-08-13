import type { Journey } from '@via/contract';
import { Pressable, ScrollView, StyleSheet, Text } from 'react-native';

import { journeyQualifierLabel } from '@/features/journey/model/qualifier-label';
import { useAppTheme } from '@/hooks/use-app-theme';
import { SHEET_GUTTER } from '@/styles/metrics';

type JourneyVariantSelectorProps = {
  journeys: Journey[];
  selectedIndex: number;
  onSelect: (index: number) => void;
};

export function JourneyVariantSelector({ journeys, selectedIndex, onSelect }: JourneyVariantSelectorProps) {
  const { colors } = useAppTheme();
  const options = uniqueQualifiers(journeys);
  return (
    <ScrollView horizontal contentContainerStyle={styles.content} showsHorizontalScrollIndicator={false}>
      {options.map(({ journey, index }) => (
        <Pressable
          accessibilityRole="tab"
          accessibilityState={{ selected: selectedIndex === index }}
          key={journey.id}
          onPress={() => onSelect(index)}
          style={[
            styles.pill,
            {
              backgroundColor: selectedIndex === index ? colors.primary : colors.surface,
              borderColor: selectedIndex === index ? colors.primary : colors.line,
            },
          ]}>
          <Text style={[styles.label, { color: selectedIndex === index ? '#FFFFFF' : colors.ink }]}>
            {journeyQualifierLabel(journey.qualifier)}
          </Text>
        </Pressable>
      ))}
    </ScrollView>
  );
}

function uniqueQualifiers(journeys: Journey[]) {
  const seen = new Set<Journey['qualifier']>();
  return journeys.flatMap((journey, index) => {
    if (seen.has(journey.qualifier)) return [];
    seen.add(journey.qualifier);
    return [{ journey, index }];
  });
}

const styles = StyleSheet.create({
  content: { gap: 8, paddingHorizontal: SHEET_GUTTER },
  pill: { minHeight: 38, justifyContent: 'center', paddingHorizontal: 14, borderCurve: 'continuous', borderRadius: 19, borderWidth: StyleSheet.hairlineWidth },
  label: { fontFamily: 'Inter_600SemiBold', fontSize: 13 },
});
