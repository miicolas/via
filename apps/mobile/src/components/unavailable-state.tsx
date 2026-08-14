import type { AnimationSpec, AnimationType, SFSymbol } from 'expo-symbols';
import { StyleSheet, Text, View } from 'react-native';

import { Button } from '@/components/button';
import { FadingScrollView } from '@/components/fading-scroll-view';
import { SymbolIcon } from '@/components/symbol-icon';
import { useAppTheme } from '@/hooks/use-app-theme';

type UnavailableStateProps = {
  actionLabel?: string;
  /** Omit for a static symbol. Either an effect type (`'bounce'`) or a full `AnimationSpec`. */
  animation?: AnimationType | AnimationSpec;
  description: string;
  icon: SFSymbol;
  onAction?: () => void;
  /** Replays a one-shot `animation` on this interval so the badge keeps breathing. */
  replayIntervalMs?: number;
  title: string;
};

export function UnavailableState({
  actionLabel,
  animation,
  description,
  icon,
  onAction,
  replayIntervalMs,
  title,
}: UnavailableStateProps) {
  const { colors } = useAppTheme();

  return (
    <FadingScrollView
      bounces={false}
      contentContainerStyle={styles.container}
      showsVerticalScrollIndicator={false}
      style={styles.scroll}>
      <View style={styles.content}>
        <View
          style={[
            styles.iconBadge,
            {
              backgroundColor: colors.accentSoft,
              boxShadow: `0 1px 3px ${colors.shadow}`,
            },
          ]}>
          <SymbolIcon
            animation={animation}
            color={colors.primary}
            name={icon}
            replayIntervalMs={replayIntervalMs}
            size={26}
          />
        </View>

        <View style={styles.copy}>
          <Text selectable style={[styles.title, { color: colors.ink }]}>
            {title}
          </Text>
          <Text selectable style={[styles.description, { color: colors.muted }]}>
            {description}
          </Text>
        </View>

        {actionLabel && onAction ? (
          <Button
            label={actionLabel}
            onPress={onAction}
            size="large"
            tint={colors.primary}
            variant="prominent"
          />
        ) : null}
      </View>
    </FadingScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: {
    flex: 1,
  },
  container: {
    flexGrow: 1,
    justifyContent: 'center',
    paddingHorizontal: 24,
    paddingVertical: 16,
  },
  content: {
    alignItems: 'center',
    alignSelf: 'center',
    gap: 14,
    maxWidth: 330,
    width: '100%',
  },
  iconBadge: {
    alignItems: 'center',
    justifyContent: 'center',
    width: 56,
    height: 56,
    borderRadius: 28,
  },
  copy: {
    alignItems: 'center',
    gap: 4,
  },
  title: {
    fontFamily: 'Archivo_800ExtraBold',
    fontSize: 20,
    lineHeight: 25,
    letterSpacing: -0.4,
    textAlign: 'center',
  },
  description: {
    maxWidth: 300,
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    lineHeight: 19,
    textAlign: 'center',
  },
});
