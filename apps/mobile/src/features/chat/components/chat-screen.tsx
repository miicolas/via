import { useLocalSearchParams } from 'expo-router';
import { useEffect, useRef } from 'react';
import { KeyboardAvoidingView, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { ChatInput } from '@/features/chat/components/chat-input';
import { ChatMessageList } from '@/features/chat/components/chat-message-list';
import { useViaChatContext } from '@/features/chat/hooks/use-via-chat-context';
import { useAppTheme } from '@/hooks/use-app-theme';
import { SHEET_GUTTER } from '@/styles/metrics';

type ChatScreenProps = {
  toolbarHeight?: number;
};

/** The full Via conversation, opened by "Répondre" — it continues the card's exchange. */
export function ChatScreen({ toolbarHeight = 0 }: ChatScreenProps) {
  const { colors } = useAppTheme();
  const insets = useSafeAreaInsets();
  const { ask, error, messages, send, status } = useViaChatContext();

  // Deep links may hand a phrase over as `q`; it opens a fresh exchange.
  const { q } = useLocalSearchParams<{ q?: string }>();
  const openedWith = useRef(false);
  useEffect(() => {
    const phrase = typeof q === 'string' ? q.trim() : '';
    if (openedWith.current || !phrase || messages.length > 0) return;
    openedWith.current = true;
    ask(phrase);
  }, [ask, messages.length, q]);

  const busy = status === 'submitted' || status === 'streaming';

  return (
    <View
      style={[styles.container, { backgroundColor: colors.surface, paddingTop: toolbarHeight }]}
    >
      <View style={styles.header}>
        <Text style={[styles.title, { color: colors.ink }]}>Via</Text>
      </View>

      <KeyboardAvoidingView
        behavior="padding"
        style={styles.body}>
        <ChatMessageList messages={messages} thinking={status === 'submitted'} />
        {error ? (
          <Text style={[styles.error, { color: colors.muted }]}>
            Via est momentanément indisponible. Réessaie dans un instant.
          </Text>
        ) : null}
        <View style={{ paddingBottom: insets.bottom + 4 }}>
          <ChatInput disabled={busy} onSend={send} />
        </View>
      </KeyboardAvoidingView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: SHEET_GUTTER,
    paddingBottom: 10,
  },
  title: { fontFamily: 'Archivo_700Bold', fontSize: 22, lineHeight: 27 },
  body: { flex: 1 },
  error: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    paddingHorizontal: SHEET_GUTTER,
    paddingBottom: 6,
  },
});
