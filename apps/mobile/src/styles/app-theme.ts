import type { ColorSchemeName } from 'react-native';

export const AppThemes = {
  light: {
    accentSoft: '#E5EFEB',
    body: '#4C5450',
    control: '#D1D2D0',
    critical: '#8E2F2A',
    ground: '#F6F5F0',
    hairline: '#161A1812',
    ink: '#161A18',
    line: '#DDD9CE',
    muted: '#6C716D',
    primary: '#2F6B5B',
    shadow: 'rgba(22, 26, 24, 0.08)',
    sheetHandle: 'rgba(43, 49, 45, 0.48)',
    surface: '#FFFFFF',
    surfaceGlass: '#FFFFFFCC',
    surfaceTranslucent: '#FFFFFFE0',
    track: '#161A1810',
  },
  dark: {
    accentSoft: '#18352D',
    body: '#C2CCC6',
    control: '#575D58',
    critical: '#FFB4AB',
    ground: '#101512',
    hairline: '#F1F5F21F',
    ink: '#F1F5F2',
    line: '#343B36',
    muted: '#ABB4AE',
    primary: '#7FCDB5',
    shadow: 'rgba(0, 0, 0, 0.32)',
    sheetHandle: 'rgba(235, 240, 237, 0.72)',
    surface: '#1B211D',
    surfaceGlass: '#1B211DCC',
    surfaceTranslucent: '#1B211DE8',
    track: '#F1F5F21A',
  },
} as const;

export type AppTheme = (typeof AppThemes)[keyof typeof AppThemes];

export function resolveAppTheme(colorScheme: ColorSchemeName) {
  const resolvedScheme: keyof typeof AppThemes = colorScheme === 'dark' ? 'dark' : 'light';

  return {
    colorScheme: resolvedScheme,
    colors: AppThemes[resolvedScheme],
  } as const;
}
