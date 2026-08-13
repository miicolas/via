import type { Journey } from '@via/contract';
import { Pressable, ScrollView, StyleSheet, Text } from 'react-native';

import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';

type JourneyVariantSelectorProps = {
  journeys: Journey[];
  selectedIndex: number;
  onSelect: (index: number) => void;
};

const LABELS = new Map<Journey['qualifier'], string>([
  ['recommended', 'Recommandé'],
  ['rapid', 'Rapide'],
  ['less-walking', 'Moins à pied'],
  ['comfort', 'Assis'],
  ['walking', 'À pied'],
]);

export function JourneyVariantSelector({ journeys, selectedIndex, onSelect }: JourneyVariantSelectorProps) {
  const { colors } = useHomeMapTheme();
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
            {LABELS.get(journey.qualifier) ?? 'Option'}
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
  content: { gap: 8, paddingHorizontal: 20 },
  pill: { minHeight: 38, justifyContent: 'center', paddingHorizontal: 14, borderCurve: 'continuous', borderRadius: 19, borderWidth: StyleSheet.hairlineWidth },
  label: { fontFamily: 'Inter_600SemiBold', fontSize: 13 },
});
