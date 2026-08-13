import { expect, test } from 'bun:test';

import { relativeLuminance } from '@/lib/relative-luminance';
import { resolveAppTheme } from '@/styles/app-theme';

function contrastRatio(foreground: string, background: string) {
  const lighter = Math.max(relativeLuminance(foreground), relativeLuminance(background));
  const darker = Math.min(relativeLuminance(foreground), relativeLuminance(background));

  return (lighter + 0.05) / (darker + 0.05);
}

test('app text colors switch with the color scheme', () => {
  const light = resolveAppTheme('light');
  const dark = resolveAppTheme('dark');

  expect(dark.colorScheme).toBe('dark');
  expect(dark.colors.ink).not.toBe(light.colors.ink);
  expect(dark.colors.muted).not.toBe(light.colors.muted);
  expect(contrastRatio(dark.colors.ink, dark.colors.ground)).toBeGreaterThanOrEqual(4.5);
  expect(contrastRatio(dark.colors.muted, dark.colors.ground)).toBeGreaterThanOrEqual(4.5);
});
