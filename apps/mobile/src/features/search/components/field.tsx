import { Image, TextField, useNativeState } from '@expo/ui/swift-ui';
import {
  font,
  foregroundStyle,
  onSubmit as onSubmitModifier,
  submitLabel,
  textInputAutocapitalization,
  tint,
} from '@expo/ui/swift-ui/modifiers';
import { useEffect } from 'react';

import { SearchFieldShell } from '@/components/search-field-shell';
import { useAppTheme } from '@/hooks/use-app-theme';

type SearchFieldProps = {
  onChange: (query: string) => void;
  onFocusChange: (focused: boolean) => void;
  onSubmit: () => void;
  value: string;
};

export function SearchField({ onChange, onFocusChange, onSubmit, value }: SearchFieldProps) {
  const { colors } = useAppTheme();
  const query = useNativeState('');

  useEffect(() => {
    if (query.get() !== value) query.set(value);
  }, [query, value]);

  return (
    <SearchFieldShell>
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
    </SearchFieldShell>
  );
}
