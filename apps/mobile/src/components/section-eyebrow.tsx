import { StyleSheet, Text } from 'react-native';

import { useAppTheme } from '@/hooks/use-app-theme';

type SectionEyebrowProps = {
  label: string;
};

/** The small caps label that opens each section of the sheet. */
export function SectionEyebrow({ label }: SectionEyebrowProps) {
  const { colors } = useAppTheme();

  return <Text style={[styles.eyebrow, { color: colors.muted }]}>{label}</Text>;
}

const styles = StyleSheet.create({
  eyebrow: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 11,
    lineHeight: 14,
    letterSpacing: 1.54,
  },
});
