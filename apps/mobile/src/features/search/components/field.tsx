import { Host, HStack, Image, TextField, useNativeState } from '@expo/ui/swift-ui';
import {
  background,
  font,
  foregroundStyle,
  frame,
  padding,
  onSubmit as onSubmitModifier,
  shadow,
  shapes,
  submitLabel,
  textInputAutocapitalization,
  tint,
} from '@expo/ui/swift-ui/modifiers';
import { useEffect } from 'react';
import { StyleSheet } from 'react-native';

import { useAppTheme } from '@/hooks/use-app-theme';

type SearchFieldProps = {
  onChange: (query: string) => void;
  onFocusChange: (focused: boolean) => void;
  onSubmit: () => void;
  value: string;
};

export function SearchField({ onChange, onFocusChange, onSubmit, value }: SearchFieldProps) {
  const { colorScheme, colors } = useAppTheme();
  const query = useNativeState('');

  useEffect(() => {
    if (query.get() !== value) query.set(value);
  }, [query, value]);

  return (
    <Host colorScheme={colorScheme} style={styles.host}>
      <HStack
        alignment="center"
        spacing={10}
        modifiers={[
          padding({ horizontal: 18 }),
          frame({ height: 52 }),
          background(colors.surface, shapes.capsule()),
          shadow({ color: colors.shadow, radius: 8, y: 1 }),
        ]}>
        <Image color={colors.primary} size={17} systemName="magnifyingglass" />
        <TextField
          onFocusChange={onFocusChange}
          onTextChange={onChange}
          placeholder="Où veux-tu aller ?"
          text={query}
          modifiers={[
            font({ size: 17 }),
            foregroundStyle(colors.ink),
            onSubmitModifier(onSubmit),
            submitLabel('search'),
            textInputAutocapitalization('sentences'),
            tint(colors.primary),
          ]}
        />
      </HStack>
    </Host>
  );
}

const styles = StyleSheet.create({
  host: {
    height: 52,
    marginHorizontal: 16,
  },
});
