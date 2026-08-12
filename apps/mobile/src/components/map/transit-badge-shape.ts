import type { NetworkMode } from '@via/contract';

type TransitBadgeFrame = {
  borderRadius: number;
  height: number;
  minWidth: number;
  width?: number;
};

/** Keeps the network's visual language consistent wherever a line or mode is badged. */
export function transitBadgeFrame(mode: NetworkMode, size: number): TransitBadgeFrame {
  if (mode === 'metro') {
    return { borderRadius: size / 2, height: size, minWidth: size, width: size };
  }

  if (mode === 'rer') {
    return { borderRadius: size * 0.16, height: size, minWidth: size, width: size };
  }

  return { borderRadius: size * 0.16, height: size, minWidth: size * 1.4 };
}
