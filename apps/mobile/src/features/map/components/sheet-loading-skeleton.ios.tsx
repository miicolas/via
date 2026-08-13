import { HStack, Host, RoundedRectangle, Spacer, VStack } from '@expo/ui/swift-ui';
import {
  accessibilityElement,
  accessibilityLabel,
  animation,
  Animation,
  frame,
  foregroundStyle,
  opacity,
  padding,
} from '@expo/ui/swift-ui/modifiers';
import { useEffect, useState } from 'react';
import { StyleSheet } from 'react-native';
import { useReducedMotion } from 'react-native-reanimated';

import { useAppTheme } from '@/hooks/use-app-theme';

const PULSE_INTERVAL_MS = 500;
const PULSE_DURATION_SECONDS = 0.25;
const ROW_STAGGER_SECONDS = 0.04;
const ROWS = [
  { destinationWidth: 112, detailWidth: 76, timingWidth: 58 },
  { destinationWidth: 96, detailWidth: 64, timingWidth: 52 },
  { destinationWidth: 120, detailWidth: 84, timingWidth: 62 },
  { destinationWidth: 104, detailWidth: 72, timingWidth: 56 },
] as const;

export function SheetLoadingSkeleton() {
  const { colorScheme, colors } = useAppTheme();
  const reduceMotion = useReducedMotion();
  const [isDimmed, setIsDimmed] = useState(false);

  useEffect(() => {
    if (reduceMotion) return;

    const timer = setInterval(() => setIsDimmed((value) => !value), PULSE_INTERVAL_MS);
    return () => clearInterval(timer);
  }, [reduceMotion]);

  const fillModifiers = (delay = 0) => [
    foregroundStyle(colors.line),
    opacity(reduceMotion ? 0.64 : isDimmed ? 0.48 : 0.82),
    ...(reduceMotion
      ? []
      : [
          animation(
            Animation.easeInOut({ duration: PULSE_DURATION_SECONDS }).delay(delay),
            isDimmed
          ),
        ]),
  ];

  return (
    <Host colorScheme={colorScheme} pointerEvents="none" style={styles.host}>
      <VStack
        alignment="leading"
        spacing={0}
        modifiers={[
          padding({ horizontal: 20, top: 8 }),
          frame({ maxWidth: Infinity, alignment: 'topLeading' }),
          accessibilityElement('ignore'),
          accessibilityLabel('Chargement des données du réseau'),
        ]}>
        <HStack spacing={16} modifiers={[frame({ height: 60, maxWidth: Infinity })]}>
          <RoundedRectangle
            cornerRadius={6}
            modifiers={[frame({ width: 176, height: 22 }), ...fillModifiers()]}
          />
          <Spacer />
          <RoundedRectangle
            cornerRadius={5}
            modifiers={[frame({ width: 78, height: 14 }), ...fillModifiers()]}
          />
        </HStack>

        {ROWS.map((row, index) => {
          const delay = index * ROW_STAGGER_SECONDS;

          return (
            <HStack
              key={row.destinationWidth}
              alignment="center"
              spacing={14}
              modifiers={[frame({ height: 92, maxWidth: Infinity })]}>
              <RoundedRectangle
                cornerRadius={14}
                modifiers={[frame({ width: 50, height: 50 }), ...fillModifiers(delay)]}
              />
              <VStack alignment="leading" spacing={8}>
                <RoundedRectangle
                  cornerRadius={5}
                  modifiers={[
                    frame({ width: row.destinationWidth, height: 18 }),
                    ...fillModifiers(delay),
                  ]}
                />
                <RoundedRectangle
                  cornerRadius={4}
                  modifiers={[
                    frame({ width: row.detailWidth, height: 11 }),
                    ...fillModifiers(delay),
                  ]}
                />
              </VStack>
              <Spacer />
              <VStack alignment="trailing" spacing={7}>
                <RoundedRectangle
                  cornerRadius={6}
                  modifiers={[
                    frame({ width: row.timingWidth, height: 24 }),
                    ...fillModifiers(delay),
                  ]}
                />
                <RoundedRectangle
                  cornerRadius={4}
                  modifiers={[frame({ width: 64, height: 10 }), ...fillModifiers(delay)]}
                />
              </VStack>
            </HStack>
          );
        })}
      </VStack>
    </Host>
  );
}

const styles = StyleSheet.create({
  host: { flex: 1 },
});
