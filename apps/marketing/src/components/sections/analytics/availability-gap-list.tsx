import {
  elevatorAvailability,
  unavailableDaysPerYear,
} from "@/constants/analytics-data";
import { TransitText } from "@/components/ui/transit-text";
import type { AnalyticsContent } from "@/constants/analytics-page";
import type { ReactNode } from "react";

function formatPercent(value: number): string {
  return `${value.toLocaleString("fr-FR", { minimumFractionDigits: 1 })} %`;
}

function formatDelta(delta: number): string {
  const rounded = Math.round(delta * 10) / 10;
  const sign = rounded > 0 ? "+" : "−";
  return `${sign}${Math.abs(rounded).toLocaleString("fr-FR", { minimumFractionDigits: 1 })}`;
}

export function AvailabilityGapList({
  content,
}: {
  readonly content: AnalyticsContent["elevators"]["gap"];
}): ReactNode {
  return (
    <ul>
      {elevatorAvailability.map((network) => {
        const delta = network.result - network.target;
        const above = delta >= 0;

        return (
          <li
            key={network.network}
            className="flex items-baseline gap-3 border-t border-white/15 py-3.5 first:border-t-0 first:pt-0"
          >
            <span className="min-w-0 flex-1">
              <span className="block truncate text-sm font-semibold text-white">
                <TransitText>{network.shortName}</TransitText>
              </span>
              <span className="block text-xs text-white/60">
                {unavailableDaysPerYear(network.result)} jours par an sans
                ascenseur
              </span>
            </span>
            <span className="shrink-0 text-sm font-medium text-white/80 tabular-nums">
              {formatPercent(network.result)}
            </span>
            <span
              className={`shrink-0 rounded-full px-2 py-1 text-xs font-semibold tabular-nums ${
                above ? "bg-white/18 text-white" : "bg-[#ff453a] text-white"
              }`}
              aria-label={`${formatDelta(delta)} point ${above ? content.aboveLabel : content.belowLabel}`}
            >
              {formatDelta(delta)}
            </span>
          </li>
        );
      })}
    </ul>
  );
}
