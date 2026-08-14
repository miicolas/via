import { StyleSheet, Text, View } from 'react-native';

import { LineBadge, type LineBadgeRoute } from '@/components/map/line-badge';
import { SymbolIcon } from '@/components/symbol-icon';
import { useAppTheme } from '@/hooks/use-app-theme';

const BADGE_SIZE = 20;

type JourneyDisruptionNoteProps = {
  /** The line the warning is about. Falls back to a critical glyph when unknown. */
  route?: LineBadgeRoute;
  text: string;
  /** `critical` paints the text red for the detail timeline. Default keeps the card's body tone. */
  tone?: 'body' | 'critical';
};

/** Explains, inside the card, what the network reported about this route. */
export function JourneyDisruptionNote({ route, text, tone = 'body' }: JourneyDisruptionNoteProps) {
  const { colors } = useAppTheme();

  return (
    <View style={styles.note}>
      {route ? (
        <LineBadge route={route} size={BADGE_SIZE} />
      ) : (
        <SymbolIcon
          animation="pulse"
          color={colors.critical}
          name="exclamationmark.circle.fill"
          size={BADGE_SIZE}
        />
      )}
      <Text selectable style={[styles.text, { color: colors[tone] }]}>
        {text}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  note: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 8,
  },
  text: {
    minWidth: 0,
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    lineHeight: 20,
  },
});
