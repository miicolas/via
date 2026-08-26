import { TransitText } from "@/components/ui/transit-text";
import type { ArticlePhase } from "@/lib/blog/schema";
import { formatDateRange } from "@/lib/blog/status";
import type { ReactNode } from "react";

type PhaseState = "past" | "current" | "future";

function stateOf(phase: ArticlePhase, today: string): PhaseState {
  if (today > phase.to) return "past";
  if (today < phase.from) return "future";
  return "current";
}

/**
 * Le calendrier d’un chantier en plusieurs actes.
 *
 * Un chantier découpé en phases pose une question précise — « et moi, la
 * semaine prochaine ? » — à laquelle une liste de dates ne répond pas. La
 * phase en cours est donc distinguée, et les phases passées s’effacent sans
 * disparaître : elles racontent où on en est.
 */
export function WorksPhases({
  phases,
  today,
}: {
  readonly phases: readonly ArticlePhase[];
  readonly today: string;
}): ReactNode {
  if (phases.length === 0) return null;

  return (
    <ol className="my-8 space-y-0">
      {phases.map((phase, index) => {
        const state = stateOf(phase, today);
        const isLast = index === phases.length - 1;

        return (
          <li key={`${phase.from}-${phase.label}`} className="relative flex gap-4 pb-6 last:pb-0">
            {/* Le fil qui relie les phases, interrompu après la dernière. */}
            {!isLast && (
              <span
                className="absolute top-4 bottom-0 left-[7px] w-px bg-foreground/15"
                aria-hidden="true"
              />
            )}

            <span
              className={`relative z-10 mt-1.5 size-[15px] shrink-0 rounded-full border-2 ${
                state === "current"
                  ? "border-accent bg-accent"
                  : state === "past"
                    ? "border-foreground/20 bg-foreground/20"
                    : "border-foreground/25 bg-background"
              }`}
              aria-hidden="true"
            />

            <div className={state === "past" ? "opacity-55" : undefined}>
              <p className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
                <span className="font-medium text-foreground">
                  <TransitText>{phase.label}</TransitText>
                </span>
                {state === "current" && (
                  <span className="text-xs font-semibold text-accent uppercase">
                    En cours
                  </span>
                )}
              </p>
              <p className="mt-0.5 text-sm text-muted-foreground">
                {formatDateRange(phase.from, phase.to)}
              </p>
              {phase.note !== undefined && (
                <p className="mt-1.5 leading-7 text-foreground/85">
                  <TransitText>{phase.note}</TransitText>
                </p>
              )}
            </div>
          </li>
        );
      })}
    </ol>
  );
}
