import { ScrollView, StyleSheet } from 'react-native';

import { Button } from '@/components/button';
import { GlassSurface } from '@/components/glass-surface';
import { LineBadge } from '@/components/map/line-badge';
import type { NetworkRoute } from '@via/contract';

const BADGE_SIZE = 31;

type RouteSelectorProps = {
  routes: NetworkRoute[];
  selectedRouteId: string | undefined;
  onSelect: (routeId: string) => void;
};

/** Horizontal strip of line badges used to pick the displayed line. */
export function RouteSelector({ routes, selectedRouteId, onSelect }: RouteSelectorProps) {
  return (
    <GlassSurface variant="tinted" style={styles.glass}>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.content}
      >
        {routes.map((route) => {
          const selected = route.id === selectedRouteId;
          return (
            <Button
              key={route.id}
              accessibilityState={{ selected }}
              contentStyle={[styles.item, selected && styles.itemSelected]}
              label={`Sélectionner la ligne ${route.shortName}`}
              onPress={() => onSelect(route.id)}
              variant="plain">
              <LineBadge route={route} size={BADGE_SIZE} />
            </Button>
          );
        })}
      </ScrollView>
    </GlassSurface>
  );
}

const styles = StyleSheet.create({
  glass: {
    height: 54,
    borderRadius: 20,
    borderCurve: 'continuous',
    overflow: 'hidden',
  },
  content: {
    alignItems: 'center',
    gap: 5,
    paddingHorizontal: 7,
    paddingVertical: 6,
  },
  item: {
    minWidth: 42,
    height: 42,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 15,
    borderCurve: 'continuous',
  },
  itemSelected: {
    backgroundColor: 'rgba(255,255,255,0.72)',
    boxShadow: '0 1px 5px rgba(0,0,0,0.14)',
  },
});
