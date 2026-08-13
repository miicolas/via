import { StyleSheet, Text, View } from 'react-native';

import { SectionEyebrow } from '@/components/section-eyebrow';
import { useAppTheme } from '@/hooks/use-app-theme';
import { SHEET_GUTTER } from '@/styles/metrics';

type JourneyResultsHeadingProps = {
  /** Where the journeys lead, and how far — kept on one line beside the label. */
  detail: string;
};

/** Names the section and repeats the destination, so the list is never orphaned. */
export function JourneyResultsHeading({ detail }: JourneyResultsHeadingProps) {
  const { colors } = useAppTheme();

  return (
    <View style={styles.heading}>
      <SectionEyebrow label="ITINÉRAIRES" />
      <Text numberOfLines={1} selectable style={[styles.detail, { color: colors.muted }]}>
        {detail}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  heading: {
    minWidth: 0,
    flexDirection: 'row',
    alignItems: 'baseline',
    justifyContent: 'space-between',
    gap: 16,
    paddingBottom: 4,
    paddingHorizontal: SHEET_GUTTER,
  },
  detail: {
    minWidth: 0,
    flexShrink: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    lineHeight: 18,
    textAlign: 'right',
  },
});
