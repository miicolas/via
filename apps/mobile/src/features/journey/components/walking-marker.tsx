import type { ColorValue } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';

type JourneyWalkingMarkerProps = {
  color: ColorValue;
};

/** Apple's motion-annotated walking cue, with only its native layers pulsing. */
export function JourneyWalkingMarker({ color }: JourneyWalkingMarkerProps) {
  return (
    <SymbolIcon
      animation={{
        effect: { type: 'pulse' },
        repeating: true,
        speed: 1.2,
      }}
      color={color}
      name="figure.walk.motion"
      size={21}
      weight="regular"
    />
  );
}
