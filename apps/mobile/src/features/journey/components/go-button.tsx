import { Button } from '@/components/button';
import { useAppTheme } from '@/hooks/use-app-theme';

type JourneyGoButtonProps = {
  accessibilityLabel: string;
  /** Stretches the pill across its row, for the detail footer. Default hugs content. */
  grow?: boolean;
  label?: string;
  onPress: () => void;
};

/** The single committing action of the results screen. */
export function JourneyGoButton({
  accessibilityLabel,
  grow = false,
  label = 'Voir l’itinéraire',
  onPress,
}: JourneyGoButtonProps) {
  const { colors } = useAppTheme();

  return (
    <Button
      accessibilityLabel={accessibilityLabel}
      grow={grow}
      label={label}
      onPress={onPress}
      shape="capsule"
      size="large"
      systemImage="paperplane.fill"
      tint={colors.primary}
      variant="prominent"
    />
  );
}
