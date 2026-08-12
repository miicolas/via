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
import { StyleSheet } from 'react-native';

import { HomeMapTheme } from '@/features/home-map/styles/theme';

type HomeSearchFieldProps = {
  onChange: (query: string) => void;
};

export function HomeSearchField({ onChange }: HomeSearchFieldProps) {
  const query = useNativeState('');

  return (
    <Host colorScheme="light" style={styles.host}>
      <HStack
        alignment="center"
        spacing={10}
        modifiers={[
          padding({ horizontal: 18 }),
          frame({ height: 52 }),
          background(HomeMapTheme.surface, shapes.capsule()),
          shadow({ color: '#161A1814', radius: 8, y: 1 }),
        ]}>
        <Image color={HomeMapTheme.primary} size={17} systemName="magnifyingglass" />
        <TextField
          onTextChange={onChange}
          placeholder="Rechercher une station"
          text={query}
          modifiers={[
            autocorrectionDisabled(),
            font({ size: 17 }),
            foregroundStyle(HomeMapTheme.ink),
            submitLabel('search'),
            textInputAutocapitalization('words'),
            tint(HomeMapTheme.primary),
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
