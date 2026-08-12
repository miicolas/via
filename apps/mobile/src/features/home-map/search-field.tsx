import { Host, TextInput, useNativeState } from '@expo/ui';
import { SymbolView } from 'expo-symbols';
import { StyleSheet, View } from 'react-native';

import { HomeMapTheme } from '@/features/home-map/theme';

type HomeSearchFieldProps = {
  onChange: (query: string) => void;
};

export function HomeSearchField({ onChange }: HomeSearchFieldProps) {
  const query = useNativeState('');

  return (
    <View style={styles.container}>
      <Host colorScheme="light" seedColor={HomeMapTheme.primary} style={styles.host}>
        <TextInput
          autoCapitalize="words"
          autoCorrect={false}
          enterKeyHint="search"
          onChangeText={onChange}
          placeholder="Rechercher une station"
          placeholderTextColor={HomeMapTheme.muted}
          returnKeyType="search"
          selectionColor={HomeMapTheme.primary}
          textStyle={styles.text}
          value={query}
          style={styles.input}
        />
      </Host>
      <View pointerEvents="none" style={styles.icon}>
        <SymbolView
          name={{ ios: 'magnifyingglass', android: 'search' }}
          size={18}
          tintColor={HomeMapTheme.primary}
          weight="medium"
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    height: 52,
    marginHorizontal: 16,
    borderRadius: 18,
    borderCurve: 'continuous',
    backgroundColor: HomeMapTheme.surface,
    boxShadow: '0 1px 8px rgba(22, 26, 24, 0.08)',
  },
  host: {
    height: 52,
  },
  input: {
    height: 52,
    paddingLeft: 48,
    paddingRight: 18,
    borderRadius: 18,
    borderCurve: 'continuous',
    backgroundColor: HomeMapTheme.surface,
  },
  text: {
    color: HomeMapTheme.ink,
    fontFamily: 'Inter_400Regular',
    fontSize: 17,
    lineHeight: 22,
  },
  icon: {
    position: 'absolute',
    left: 17,
    top: 17,
    width: 18,
    height: 18,
  },
});
