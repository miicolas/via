import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/button';
import { JourneyGoButton } from '@/features/journey/components/go-button';
import { useAppTheme } from '@/hooks/use-app-theme';
import { SHEET_GUTTER } from '@/styles/metrics';

type JourneyDetailFooterProps = {
  destinationName: string;
  onGo: () => void;
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
        label="J’y vais !"
        onPress={onGo}
      />
      {onRemind ? (
        <Button
          iconOnly
          label="M’alerter avant le départ"
          onPress={onRemind}
          shape="circle"
          size="large"
          systemImage="bell"
          tint={colors.primary}
          variant="glass"
        />
      ) : null}
    </View>
  );
}

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
});
