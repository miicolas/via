import type { Journey } from '@via/contract';
import { StyleSheet, Text } from 'react-native';

import { journeyQualifierLabel } from '@/features/journey/model/qualifier-label';
import { useAppTheme } from '@/hooks/use-app-theme';

type JourneyQualifierTagProps = {
  qualifier: Journey['qualifier'];
};

/** What sets an alternative apart, said quietly — it is a hint, not a headline. */
export function JourneyQualifierTag({ qualifier }: JourneyQualifierTagProps) {
  const { colors } = useAppTheme();

  return (
    <Text numberOfLines={1} style={[styles.tag, { color: colors.muted }]}>
      {journeyQualifierLabel(qualifier)}
    </Text>
  );
}

const styles = StyleSheet.create({
  tag: {
    fontFamily: 'Inter_500Medium',
    fontSize: 13,
    lineHeight: 17,
  },
});
