import { Host, HStack, Image, TextField, useNativeState } from '@expo/ui/swift-ui';
import {
  autocorrectionDisabled,
  background,
  font,
  foregroundStyle,
  frame,
  padding,
  shadow,
  shapes,
  submitLabel,
  textInputAutocapitalization,
  tint,
} from '@expo/ui/swift-ui/modifiers';
import { useEffect } from 'react';
import { StyleSheet } from 'react-native';

import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';

type HomeSearchFieldProps = {
  onChange: (query: string) => void;
  value: string;
};

export function HomeSearchField({ onChange, value }: HomeSearchFieldProps) {
  const { colorScheme, colors } = useHomeMapTheme();
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
          onTextChange={onChange}
          placeholder="Rechercher une station"
          text={query}
          modifiers={[
            autocorrectionDisabled(),
            font({ size: 17 }),
            foregroundStyle(colors.ink),
            submitLabel('search'),
            textInputAutocapitalization('words'),
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
