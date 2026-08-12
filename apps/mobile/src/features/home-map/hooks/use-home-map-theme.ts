import { resolveHomeMapTheme } from '@/features/home-map/styles/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';

export function useHomeMapTheme() {
  return resolveHomeMapTheme(useColorScheme());
}
