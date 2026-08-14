import type { ReactNode } from 'react';
import { StyleSheet, type StyleProp, type ViewStyle } from 'react-native';

import { Button } from '@/components/button';

type IconButtonProps = {
  accessibilityLabel: string;
  onPress: () => void;
  children: ReactNode;
  size?: number;
  style?: StyleProp<ViewStyle>;
};

/** A round icon control backed by the app's shared surface material. */
export function IconButton({
  accessibilityLabel,
  children,
  onPress,
  size = 44,
  style,
}: IconButtonProps) {
  const frame = { width: size, height: size, borderRadius: size / 2 };

  return (
    <Button
      contentStyle={[styles.content, frame]}
      iconOnly
      label={accessibilityLabel}
      onPress={onPress}
      shape="circle"
      style={[frame, style]}
      size="small"
      variant="glass">
      {children}
    </Button>
  );
}

const styles = StyleSheet.create({
  content: { alignItems: 'center', justifyContent: 'center' },
});
