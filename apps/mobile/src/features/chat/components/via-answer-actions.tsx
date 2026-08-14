import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/button';
import { useAppTheme } from '@/hooks/use-app-theme';

type ViaAnswerActionsProps = {
  onGo?: () => void;
  onReply: () => void;
};

/** The card's two follow-ups: launch the journey, or keep talking to Via. */
export function ViaAnswerActions({ onGo, onReply }: ViaAnswerActionsProps) {
  const { colors } = useAppTheme();

  return (
    <View style={styles.row}>
      {onGo ? (
        <Button
          grow
          label="Voir l’itinéraire"
          onPress={onGo}
          size="regular"
          systemImage="location.fill"
          tint={colors.primary}
          variant="prominent"
        />
      ) : null}
      <Button
        grow
        label="Répondre"
        onPress={onReply}
        size="regular"
        systemImage="bubble.left"
        tint={colors.ink}
        variant="bordered"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', flexWrap: 'wrap', gap: 10, paddingTop: 4 },
});
