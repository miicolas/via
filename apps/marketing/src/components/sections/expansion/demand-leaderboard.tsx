"use client";

import type { VotableCity } from "@/constants/cities";
import { expansionContent } from "@/constants/expansion";
import { useReducedMotion } from "@/lib/motion";
import { motion } from "motion/react";
import type { ReactNode } from "react";

export interface LeaderboardEntry {
  readonly city: VotableCity;
  readonly votes: number;
  readonly rank: number;
}

interface DemandLeaderboardProps {
  readonly entries: readonly LeaderboardEntry[];
  readonly totalVotes: number;
  /** `true` when the API never answered — the map stands, the count does not. */
  readonly unavailable: boolean;
  readonly onSelect: (city: VotableCity) => void;
}

/**
 * What the votes add up to, in the open. The bars are read against the leader
 * rather than the total, so a first place with a third of the voices still
 * fills its row and the gaps between cities stay legible.
 */
export function DemandLeaderboard({
  entries,
  totalVotes,
  unavailable,
  onSelect,
}: DemandLeaderboardProps): ReactNode {
  const reducedMotion = useReducedMotion();

  if (unavailable) {
    return (
      <p className="mx-auto max-w-md text-center text-sm text-white/45">
        {expansionContent.leaderboard.unavailable}
      </p>
    );
  }

  if (entries.length === 0) {
    return (
      <p className="mx-auto max-w-md text-center text-sm text-white/45">
        {expansionContent.leaderboard.empty}
      </p>
    );
  }

  const leader = entries[0]?.votes ?? 1;

  return (
    <div className="mx-auto max-w-xl">
      <div className="mb-4 flex items-baseline justify-between gap-4">
        <h3 className="text-[13px] font-medium text-white/70">
          {expansionContent.leaderboard.title}
        </h3>
        <p className="text-[12px] text-white/40 tabular-nums">
          {expansionContent.leaderboard.total(totalVotes)}
        </p>
      </div>

      <ol className="flex flex-col gap-0.5">
        {entries.map((entry, index) => (
          <li key={entry.city.slug}>
            <button
              type="button"
              onClick={() => onSelect(entry.city)}
              className="focus-ring group flex w-full items-center gap-4 rounded-2xl px-3 py-2.5 text-left transition-colors duration-200 hover:bg-white/6 active:bg-white/10"
            >
              <span className="w-5 shrink-0 text-[12px] text-white/35 tabular-nums">
                {entry.rank}
              </span>
              <span className="w-28 shrink-0 truncate text-[14px] font-medium text-white/90">
                {entry.city.name}
              </span>
              <span
                className="relative h-1.5 flex-1 overflow-hidden rounded-full bg-white/8"
                aria-hidden="true"
              >
                <motion.span
                  className="absolute inset-y-0 left-0 rounded-full bg-gradient-to-r from-[#1872f7] to-[#4D96FF]"
                  initial={reducedMotion ? false : { scaleX: 0 }}
                  animate={{ scaleX: 1 }}
                  style={{
                    width: `${Math.max(6, (entry.votes / leader) * 100)}%`,
                    transformOrigin: "left center",
                  }}
                  transition={
                    reducedMotion
                      ? { duration: 0 }
                      : {
                          type: "spring",
                          bounce: 0,
                          duration: 0.7,
                          delay: 0.06 * index,
                        }
                  }
                />
              </span>
              <span className="w-12 shrink-0 text-right text-[12px] text-white/55 tabular-nums">
                {entry.votes.toLocaleString("fr-FR")}
              </span>
            </button>
          </li>
        ))}
      </ol>
    </div>
  );
}
