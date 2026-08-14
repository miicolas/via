import type { UIMessage } from 'ai';
import { useRef } from 'react';
import { ScrollView, StyleSheet, Text } from 'react-native';

import { FadingScrollView } from '@/components/fading-scroll-view';
import { ChatMessage } from '@/features/chat/components/chat-message';
import { useAppTheme } from '@/hooks/use-app-theme';
import { SHEET_GUTTER } from '@/styles/metrics';

type ChatMessageListProps = {
  messages: UIMessage[];
  thinking: boolean;
};

/** The scrolling transcript, pinned to the latest message while Via streams. */
export function ChatMessageList({ messages, thinking }: ChatMessageListProps) {
  const { colors } = useAppTheme();
  const scrollRef = useRef<ScrollView>(null);

  return (
    <FadingScrollView
      contentContainerStyle={styles.content}
      keyboardDismissMode="interactive"
      onContentSizeChange={() => scrollRef.current?.scrollToEnd({ animated: true })}
      ref={scrollRef}
      showsVerticalScrollIndicator={false}>
      {messages.map((message) => (
        <ChatMessage key={message.id} message={message} />
      ))}
      {thinking ? (
        <Text style={[styles.thinking, { color: colors.muted }]}>Via réfléchit…</Text>
      ) : null}
    </FadingScrollView>
  );
}

const styles = StyleSheet.create({
  content: { gap: 14, paddingHorizontal: SHEET_GUTTER, paddingTop: 12, paddingBottom: 16 },
  thinking: { fontFamily: 'Inter_400Regular', fontSize: 13, paddingHorizontal: 4 },
});
