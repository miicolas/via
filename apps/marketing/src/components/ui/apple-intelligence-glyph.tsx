import type { ReactNode } from "react";

interface AppleIntelligenceGlyphProps {
  readonly className?: string;
  readonly strokeWidth?: number;
}

export function AppleIntelligenceGlyph({
  className,
  strokeWidth = 1.6,
}: AppleIntelligenceGlyphProps): ReactNode {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      className={className}
      aria-hidden="true"
    >
      {[0, 45, 90, 135].map((angle) => (
        <ellipse
          key={angle}
          cx="12"
          cy="12"
          rx="9.5"
          ry="3.9"
          transform={`rotate(${angle} 12 12)`}
        />
      ))}
    </svg>
  );
}
