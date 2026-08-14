import { useState } from 'react';
import { Pressable, StyleSheet, TextInput, View } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { useAppTheme } from '@/hooks/use-app-theme';
import { SHEET_GUTTER } from '@/styles/metrics';

type ChatInputProps = {
  disabled: boolean;
  onSend: (text: string) => void;
};

/** The composer at the bottom of the Via conversation. */
export function ChatInput({ disabled, onSend }: ChatInputProps) {
  const { colors } = useAppTheme();
  const [text, setText] = useState('');
  const canSend = !disabled && text.trim().length > 0;

  const send = () => {
    if (!canSend) return;
    onSend(text.trim());
    setText('');
  };

  return (
    <View style={styles.row}>
      <TextInput
        multiline
        onChangeText={setText}
        onSubmitEditing={send}
        placeholder="Écris à Via…"
        placeholderTextColor={colors.muted}
        style={[styles.input, { backgroundColor: colors.track, color: colors.ink }]}
        submitBehavior="blurAndSubmit"
        value={text}
      />
      <Pressable
        accessibilityLabel="Envoyer"
        accessibilityRole="button"
        disabled={!canSend}
        onPress={send}
        style={[styles.send, { backgroundColor: colors.primary, opacity: canSend ? 1 : 0.4 }]}>
        <SymbolIcon color={colors.surface} name="arrow.up" size={16} />
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 10,
    paddingHorizontal: SHEET_GUTTER,
    paddingVertical: 10,
  },
  input: {
    minWidth: 0,
    flex: 1,
    minHeight: 44,
    maxHeight: 120,
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 12,
    borderRadius: 22,
    borderCurve: 'continuous',
    fontFamily: 'Inter_400Regular',
    fontSize: 15,
  },
  send: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
