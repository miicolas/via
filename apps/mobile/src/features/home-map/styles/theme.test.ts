import { expect, test } from 'bun:test';

import { resolveHomeMapTheme } from '@/features/home-map/styles/theme';

function relativeLuminance(hex: string) {
  const channels = hex
    .slice(1)
    .match(/.{2}/g)!
    .map((channel) => Number.parseInt(channel, 16) / 255)
    .map((channel) =>
      channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4
    );

  return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
}

function contrastRatio(foreground: string, background: string) {
  const lighter = Math.max(relativeLuminance(foreground), relativeLuminance(background));
  const darker = Math.min(relativeLuminance(foreground), relativeLuminance(background));

  return (lighter + 0.05) / (darker + 0.05);
}

test('home-map text colors switch with the color scheme', () => {
  const light = resolveHomeMapTheme('light');
  const dark = resolveHomeMapTheme('dark');

  expect(dark.colorScheme).toBe('dark');
  expect(dark.colors.ink).not.toBe(light.colors.ink);
  expect(dark.colors.muted).not.toBe(light.colors.muted);
  expect(contrastRatio(dark.colors.ink, dark.colors.ground)).toBeGreaterThanOrEqual(4.5);
  expect(contrastRatio(dark.colors.muted, dark.colors.ground)).toBeGreaterThanOrEqual(4.5);
});
