import { Pressable, StyleSheet, View } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { JourneyGoButton } from '@/features/journey/components/go-button';
import { useAppTheme } from '@/hooks/use-app-theme';
import { SHEET_GUTTER } from '@/styles/metrics';

type JourneyDetailFooterProps = {
  destinationName: string;
  /** Absent while navigation isn't built: the button renders but does nothing yet. */
  onGo?: () => void;
  /** Absent while departure alerts aren't built: the bell renders but does nothing yet. */
  onRemind?: () => void;
};

/** The detail screen's committing bar: go, or ask to be nudged before departure. */
export function JourneyDetailFooter({ destinationName, onGo, onRemind }: JourneyDetailFooterProps) {
  const { colors } = useAppTheme();

  return (
    <View style={[styles.footer, { borderTopColor: colors.hairline }]}>
      <JourneyGoButton
        accessibilityLabel={`Lancer l’itinéraire vers ${destinationName}`}
        grow
        onPress={onGo ?? noop}
      />
      <Pressable
        accessibilityLabel="M’alerter avant le départ"
        accessibilityRole="button"
        hitSlop={4}
        onPress={onRemind ?? noop}
        style={({ pressed }) => [
          styles.bell,
          { backgroundColor: colors.accentSoft },
          pressed && styles.pressed,
        ]}>
        <SymbolIcon
          animation={{ effect: { type: 'bounce', direction: 'up' } }}
          color={colors.primary}
          name="bell"
          size={17}
        />
      </Pressable>
    </View>
  );
}

function noop() {}

const styles = StyleSheet.create({
  footer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: SHEET_GUTTER,
    paddingTop: 12,
    paddingBottom: 8,
    borderTopWidth: StyleSheet.hairlineWidth,
  },
  bell: {
    width: 40,
    height: 40,
    flexShrink: 0,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 999,
    borderCurve: 'continuous',
  },
  pressed: { opacity: 0.65 },
});
