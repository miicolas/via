import { resolveAppTheme } from '@/styles/app-theme';
import { useColorScheme } from '@/hooks/use-color-scheme';

export function useAppTheme() {
  return resolveAppTheme(useColorScheme());
}
