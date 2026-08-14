import type { DeparturesSource, RouteBadge } from '@via/contract';
import { StyleSheet, View } from 'react-native';

import { LineBadge } from '@/components/map/line-badge';
import { DepartureDirection } from '@/features/departures/components/departure-direction';
import { useAppTheme } from '@/hooks/use-app-theme';
import type { DepartureDirectionDescriptor } from '@/features/departures/model/rows';

type DepartureRowProps = {
  route: RouteBadge;
  directions: DepartureDirectionDescriptor[];
  source: DeparturesSource;
};

export function DepartureRow({ route, directions, source }: DepartureRowProps) {
  const { colors } = useAppTheme();

  return (
    <View style={[styles.row, { borderBottomColor: colors.line }]}>
      <LineBadge route={route} size={50} />
      <View style={styles.directions}>
        {directions.map((direction, index) => (
          <DepartureDirection
            divided={index > 0}
            key={direction.destination}
            source={source}
            {...direction}
          />
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    minHeight: 92,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
    marginHorizontal: 20,
    borderBottomWidth: StyleSheet.hairlineWidth,
    paddingVertical: 4,
  },
  directions: {
    flex: 1,
    minWidth: 0,
  },
});
