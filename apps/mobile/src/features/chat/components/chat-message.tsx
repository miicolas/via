import type { UIMessage } from 'ai';
import { StyleSheet, Text, View } from 'react-native';

import { useAppTheme } from '@/hooks/use-app-theme';

const TOOL_LABELS: Record<string, string> = {
  'tool-chercher_lieu': 'Recherche du lieu…',
  'tool-calculer_itineraires': 'Calcul des itinéraires…',
};

type ChatMessageProps = { message: UIMessage };

/** One bubble of the Via conversation; tool activity shows as a muted status line. */
export function ChatMessage({ message }: ChatMessageProps) {
  const { colors } = useAppTheme();
  const isUser = message.role === 'user';

  return (
    <View style={[styles.row, isUser ? styles.userRow : styles.assistantRow]}>
      {message.parts.map((part, index) => {
        if (part.type === 'text') {
          return (
            <View
              key={`${message.id}:${index}`}
              style={[
                styles.bubble,
                isUser
                  ? [styles.userBubble, { backgroundColor: colors.primary }]
                  : [styles.assistantBubble, { backgroundColor: colors.track }],
              ]}>
              <Text style={[styles.text, { color: isUser ? colors.surface : colors.ink }]}>
                {part.text}
              </Text>
            </View>
          );
        }
        const label = TOOL_LABELS[part.type];
        if (label && 'state' in part && part.state !== 'output-available') {
          return (
            <Text key={`${message.id}:${index}`} style={[styles.status, { color: colors.muted }]}>
              {label}
            </Text>
          );
        }
        return null;
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { gap: 6 },
  userRow: { alignItems: 'flex-end' },
  assistantRow: { alignItems: 'flex-start' },
  bubble: {
    maxWidth: '85%',
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 18,
    borderCurve: 'continuous',
  },
  userBubble: { borderBottomRightRadius: 6 },
  assistantBubble: { borderBottomLeftRadius: 6 },
  text: { fontFamily: 'Inter_400Regular', fontSize: 15, lineHeight: 21 },
  status: { fontFamily: 'Inter_400Regular', fontSize: 13, lineHeight: 18, paddingHorizontal: 4 },
});
