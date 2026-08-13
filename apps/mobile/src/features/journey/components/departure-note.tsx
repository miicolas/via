import { StyleSheet, Text } from 'react-native';

import { useAppTheme } from '@/hooks/use-app-theme';
import { formatTime } from '@/lib/format-time';

type JourneyDepartureNoteProps = {
  arrivalAt: string;
  departureAt: string;
  platform?: string;
};

/**
 * When to leave and when you land. The list is ordered by arrival, so hiding the
 * arrival made the order look arbitrary.
 */
export function JourneyDepartureNote({
  arrivalAt,
  departureAt,
  platform,
}: JourneyDepartureNoteProps) {
  const { colors } = useAppTheme();
  const departure = formatTime(departureAt);
  const arrival = formatTime(arrivalAt);

  return (
    <Text
      accessibilityLabel={`Départ à ${departure}, arrivée à ${arrival}${platform ? `, quai ${platform}` : ''}`}
      numberOfLines={1}
      selectable
      style={[styles.label, { color: colors.body }]}>
      {departure} → {arrival}
      {platform ? ` · quai ${platform}` : ''}
    </Text>
  );
}

const styles = StyleSheet.create({
  label: {
    minWidth: 0,
    flex: 1,
    fontFamily: 'Inter_500Medium',
    fontSize: 14,
    lineHeight: 18,
    fontVariant: ['tabular-nums'],
  },
});
