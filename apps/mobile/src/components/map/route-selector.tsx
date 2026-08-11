import { GlassView } from 'expo-glass-effect';
import { Pressable, ScrollView, StyleSheet } from 'react-native';

import { LineBadge } from '@/components/map/line-badge';
import type { NetworkRoute } from '@/lib/network-map';

const BADGE_SIZE = 31;

type RouteSelectorProps = {
  routes: NetworkRoute[];
  selectedRouteId: string | undefined;
  onSelect: (routeId: string) => void;
};

/** Horizontal strip of line badges used to pick the displayed line. */
export function RouteSelector({ routes, selectedRouteId, onSelect }: RouteSelectorProps) {
  return (
    <GlassView glassEffectStyle="clear" style={styles.glass}>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.content}
      >
        {routes.map((route) => {
          const selected = route.id === selectedRouteId;
          return (
            <Pressable
              key={route.id}
              accessibilityRole="button"
              accessibilityLabel={`Sélectionner la ligne ${route.shortName}`}
              accessibilityState={{ selected }}
              hitSlop={4}
              onPress={() => onSelect(route.id)}
              style={({ pressed }) => [
                styles.item,
                selected && styles.itemSelected,
                pressed && styles.pressed,
              ]}
            >
              <LineBadge route={route} size={BADGE_SIZE} />
            </Pressable>
          );
        })}
      </ScrollView>
    </GlassView>
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
  pressed: { opacity: 0.6 },
});
