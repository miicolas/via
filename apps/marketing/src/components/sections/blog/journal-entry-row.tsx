import { MarketingIcon } from "@/components/ui/marketing-icon";
import { Reveal } from "@/components/ui/reveal";
import { TransitText } from "@/components/ui/transit-text";
import type { JournalEntry } from "@/constants/blog";
import type { ReactNode } from "react";

interface JournalEntryRowProps {
  readonly entry: JournalEntry;
  /** Le numéro affiché dans le sommaire, l’ouverture portant le nº 1. */
  readonly position: number;
}

export function JournalEntryRow({
  entry,
  position,
}: JournalEntryRowProps): ReactNode {
  return (
    <li>
      <Reveal
        distance={20}
        duration={0.6}
        delay={(position - 2) * 0.06}
        margin="-60px"
        className="grid gap-x-8 gap-y-4 border-t border-foreground/10 py-9 sm:grid-cols-[3rem_1fr_4rem] sm:py-10"
      >
        <span className="text-sm text-muted-foreground tabular-nums sm:pt-1.5">
          Nº {position}
        </span>

        <div>
          <span className="flex items-center gap-2 text-xs font-semibold tracking-[0.08em] text-accent uppercase">
            <MarketingIcon
              name={entry.icon}
              className="size-4 shrink-0"
              aria-hidden="true"
            />
            {entry.category}
          </span>
          <h3 className="mt-4 max-w-3xl text-2xl leading-[1.15] font-medium tracking-tight text-balance text-foreground sm:text-3xl">
            <TransitText>{entry.title}</TransitText>
          </h3>
          <p className="mt-3 max-w-2xl leading-7 text-muted-foreground">
            <TransitText>{entry.standfirst}</TransitText>
          </p>
        </div>

        <span className="text-sm text-muted-foreground sm:pt-1.5 sm:text-right">
          {entry.readingTime}
        </span>
      </Reveal>
    </li>
  );
}
