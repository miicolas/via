import { Host } from '@expo/ui';
import { Button as SwiftButton, RNHostView } from '@expo/ui/swift-ui';
import {
  accessibilityAddTraits,
  accessibilityHint,
  accessibilityLabel,
  accessibilityValue,
  buttonBorderShape,
  buttonStyle,
  containerRelativeFrame,
  controlSize,
  disabled as disabledModifier,
  font,
  labelStyle,
  lineLimit,
  tint as tintModifier,
} from '@expo/ui/swift-ui/modifiers';
import { useState, type ReactNode } from 'react';
import type { SFSymbol } from 'expo-symbols';
import {
  StyleSheet,
  View,
  type AccessibilityState,
  type ColorValue,
  type StyleProp,
  type ViewStyle,
} from 'react-native';

import {
  resolveButtonHostStyle,
  resolveButtonLabelLayout,
  resolveButtonMatchContents,
} from '@/components/button-layout';
import { useAppTheme } from '@/hooks/use-app-theme';

type ButtonVariant = 'bordered' | 'glass' | 'plain' | 'prominent';

type ButtonProps = {
  accessibilityHint?: string;
  accessibilityLabel?: string;
  accessibilityState?: AccessibilityState;
  children?: ReactNode;
  contentStyle?: StyleProp<ViewStyle>;
  disabled?: boolean;
  /** Renders directly inside an existing Expo UI Host. */
  embedded?: boolean;
  fullWidth?: boolean;
  grow?: boolean;
  iconOnly?: boolean;
  /** Visible text, or the mandatory accessible name when custom content is supplied. */
  label: string;
  onPress: () => void;
  role?: 'cancel' | 'default' | 'destructive';
  shape?: 'capsule' | 'circle' | 'roundedRectangle';
  size?: 'mini' | 'small' | 'regular' | 'large' | 'extraLarge';
  style?: StyleProp<ViewStyle>;
  systemImage?: SFSymbol;
  testID?: string;
  tint?: ColorValue;
  variant?: ButtonVariant;
};

const SWIFT_VARIANTS: Record<
  ButtonVariant,
  'bordered' | 'glass' | 'glassProminent' | 'plain'
> = {
  bordered: 'bordered',
  glass: 'glass',
  plain: 'plain',
  prominent: 'glassProminent',
};

/** The repo's single button seam: a real SwiftUI Button. */
export function Button({
  accessibilityHint: hint,
  accessibilityLabel: accessibleName,
  accessibilityState,
  children,
  contentStyle,
  disabled = false,
  embedded = false,
  fullWidth = false,
  grow = false,
  iconOnly = false,
  label,
  onPress,
  role = 'default',
  shape = 'capsule',
  size = 'regular',
  style,
  systemImage,
  testID,
  tint,
  variant = 'glass',
}: ButtonProps) {
  const { colors } = useAppTheme();
  const expands = fullWidth || grow;
  const matchContents = resolveButtonMatchContents(expands);
  const labelLayout = resolveButtonLabelLayout(expands, Boolean(children));
  const [contentHeight, setContentHeight] = useState<number>();
  const hostSizeStyle = resolveButtonHostStyle(expands, contentHeight);
  const modifiers = [
    buttonStyle(SWIFT_VARIANTS[variant]),
    buttonBorderShape(shape),
    controlSize(size),
    disabledModifier(disabled),
    tintModifier(tint ?? colors.primary),
    accessibilityLabel(accessibleName ?? label),
    ...(hint ? [accessibilityHint(hint)] : []),
    ...(iconOnly ? [labelStyle('iconOnly')] : []),
    // SwiftUI labels otherwise wrap inside a growing RN host and make a pill
    // grow vertically when the row is measured before its final width arrives.
    ...(labelLayout
      ? [
          font({ size: labelLayout.fontSize, weight: labelLayout.weight }),
          lineLimit(labelLayout.maxLines),
        ]
      : []),
    ...(expands ? [containerRelativeFrame({ axes: 'horizontal' })] : []),
    ...(accessibilityState?.selected ? [accessibilityAddTraits(['isSelected'])] : []),
    ...(accessibilityState?.expanded === undefined
      ? []
      : [accessibilityValue(accessibilityState.expanded ? 'Développé' : 'Réduit')]),
  ];
  const button = (
    <SwiftButton
      label={children ? undefined : label}
      modifiers={modifiers}
      onPress={onPress}
      role={role}
      systemImage={children ? undefined : systemImage}
      testID={testID}>
      {children ? (
        <RNHostView matchContents={matchContents.content}>
          <View
            onLayout={
              expands
                ? ({ nativeEvent: { layout } }) => {
                    setContentHeight((previous) =>
                      previous === layout.height ? previous : layout.height
                    );
                  }
                : undefined
            }
            pointerEvents="none"
            style={[styles.content, expands && styles.expandedContent, contentStyle]}>
            {children}
          </View>
        </RNHostView>
      ) : undefined}
    </SwiftButton>
  );

  if (embedded) return button;

  return (
    <Host
      // This button is embedded in an RN layout. The parent already owns the
      // keyboard/safe-area geometry; applying it again breaks matchContents.
      ignoreSafeArea="all"
      matchContents={matchContents.outer}
      style={[fullWidth && styles.fullWidth, grow && styles.grow, hostSizeStyle, style]}>
      {button}
    </Host>
  );
}

const styles = StyleSheet.create({
  content: { minWidth: 44, minHeight: 44 },
  expandedContent: { width: '100%' },
  fullWidth: { width: '100%' },
  grow: { minWidth: 0, flexGrow: 1, flexBasis: 0 },
});
