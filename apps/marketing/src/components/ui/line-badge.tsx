import type { TransitLine } from "@/constants/types";
import type { ReactNode } from "react";

/** Le logo de ligne de l’app : carré arrondi aux couleurs officielles de la ligne. */
export function LineBadge({
  line,
  className = "size-10 rounded-[0.7rem] text-lg",
}: {
  readonly line: TransitLine;
  readonly className?: string;
}): ReactNode {
  return (
    <span
      className={`grid shrink-0 place-items-center font-bold tabular-nums ${className}`}
      style={{ backgroundColor: line.color, color: line.textColor }}
    >
      {line.shortName}
    </span>
  );
}
