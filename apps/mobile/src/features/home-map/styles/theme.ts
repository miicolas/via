import type { ColorSchemeName } from 'react-native';

export const HomeMapThemes = {
  light: {
    accentSoft: '#E5EFEB',
    control: '#D1D2D0',
    critical: '#8E2F2A',
    ground: '#F6F5F0',
    ink: '#161A18',
    line: '#DDD9CE',
    muted: '#6C716D',
    primary: '#2F6B5B',
    shadow: 'rgba(22, 26, 24, 0.08)',
    sheetHandle: 'rgba(43, 49, 45, 0.48)',
    surface: '#FFFFFF',
    surfaceTranslucent: '#FFFFFFB8',
  },
  dark: {
    accentSoft: '#18352D',
    control: '#575D58',
    critical: '#FFB4AB',
    ground: '#101512',
    ink: '#F1F5F2',
    line: '#343B36',
    muted: '#ABB4AE',
    primary: '#7FCDB5',
    shadow: 'rgba(0, 0, 0, 0.32)',
    sheetHandle: 'rgba(235, 240, 237, 0.72)',
    surface: '#1B211D',
    surfaceTranslucent: '#1B211DE8',
  },
} as const;

export type HomeMapTheme = (typeof HomeMapThemes)[keyof typeof HomeMapThemes];

export function resolveHomeMapTheme(colorScheme: ColorSchemeName) {
  const resolvedScheme: keyof typeof HomeMapThemes = colorScheme === 'dark' ? 'dark' : 'light';

  return {
    colorScheme: resolvedScheme,
    colors: HomeMapThemes[resolvedScheme],
  } as const;
}
