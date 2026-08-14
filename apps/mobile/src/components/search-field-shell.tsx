import { HStack, Host } from '@expo/ui/swift-ui';
import {
  background,
  frame,
  padding,
  shadow,
  shapes,
  strokeBorder,
} from '@expo/ui/swift-ui/modifiers';
import type { PropsWithChildren } from 'react';
import { StyleSheet, type StyleProp, type ViewStyle } from 'react-native';

import { useAppTheme } from '@/hooks/use-app-theme';
import { SHEET_GUTTER } from '@/styles/metrics';

type SearchFieldShellProps = PropsWithChildren<{
  style?: StyleProp<ViewStyle>;
}>;

/** Shared native capsule used by editable and destination search fields. */
export function SearchFieldShell({ children, style }: SearchFieldShellProps) {
  const { colorScheme, colors } = useAppTheme();

  return (
    <Host
      colorScheme={colorScheme}
      // The sheet is laid out by React Native and already accounts for the
      // keyboard. Do not let this nested SwiftUI host add a second inset.
      ignoreSafeArea="all"
      style={[styles.host, styles.gutter, style]}>
      <HStack
        alignment="center"
        spacing={10}
        modifiers={[
          padding({ horizontal: 18 }),
          frame({ height: 52 }),
          background(colors.surfaceGlass, shapes.capsule()),
          strokeBorder({ color: colors.hairline, shape: 'capsule', style: { lineWidth: 0.5 } }),
          shadow({ color: colors.shadow, radius: 8, y: 1 }),
        ]}>
        {children}
      </HStack>
    </Host>
  );
}

const styles = StyleSheet.create({
  host: {
    height: 52,
    minWidth: 0,
  },
  gutter: { marginHorizontal: SHEET_GUTTER },
});
