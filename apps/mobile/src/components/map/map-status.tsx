import { View } from 'react-native';

import { NetworkErrorCard } from '@/components/map/network-error-card';
import { NetworkLoadingPill } from '@/components/map/network-loading-pill';
import type { NetworkState } from '@/lib/metro-network';

type MapStatusProps = {
  /**
   * The state itself, not a variable to re-derive it from. This module used to
   * ignore the status it was given and work out its own from whether an error
   * string was set — a third derivation of one two-state machine.
   */
  state: Extract<NetworkState, { status: 'loading' | 'error' }>;
  onRetry: () => void;
};

/** Floating Liquid Glass status shown while the network loads, or when it failed to. */
export function MapStatus({ state, onRetry }: MapStatusProps) {
  return (
    <View accessibilityLiveRegion="polite">
      {state.status === 'error' ? (
        <NetworkErrorCard message={state.message} onRetry={onRetry} />
      ) : (
        <NetworkLoadingPill />
      )}
    </View>
  );
}
