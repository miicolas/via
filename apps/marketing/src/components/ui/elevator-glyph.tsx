import type { ReactNode } from "react";

interface ElevatorGlyphProps {
  readonly className?: string;
  readonly strokeWidth?: number;
}

/** Pictogramme ascenseur (ISO 7001) : cabine et flèches montée / descente. */
export function ElevatorGlyph({
  className,
  strokeWidth = 2,
}: ElevatorGlyphProps): ReactNode {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden="true"
    >
      <rect x="3" y="2.5" width="18" height="19" rx="3" />
      <path d="M8.75 15.5V9m0 0-2 2.25m2-2.25 2 2.25" />
      <path d="M15.25 8.5V15m0 0 2-2.25M15.25 15l-2-2.25" />
    </svg>
  );
}
