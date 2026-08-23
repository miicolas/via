"use client";

import type { FeaturesContent } from "@/constants/features";
import { motion, useReducedMotion } from "motion/react";
import { useState, type ReactNode } from "react";

const BAR_HEIGHTS = ["h-3", "h-5", "h-6"] as const;

export function CrowdingDemo({
  content,
}: {
  readonly content: FeaturesContent["highlights"]["crowding"];
}): ReactNode {
  const reduceMotion = useReducedMotion();
  const [levels, setLevels] = useState<readonly number[]>(
    content.rows.map((row) => row.initialLevel),
  );

  const cycle = (rowIndex: number): void => {
    setLevels((current) =>
      current.map((level, index) =>
        index === rowIndex ? (level + 1) % content.levels.length : level,
      ),
    );
  };

  return (
    <div className="rounded-[1.75rem] border border-black/8 bg-white/94 p-2.5 shadow-[0_24px_70px_rgba(0,0,0,0.14)]">
      {content.rows.map((row, rowIndex) => {
        const level = content.levels[levels[rowIndex] ?? 0] ?? content.levels[0];

        return (
          <motion.button
            key={row.station}
            type="button"
            onClick={() => cycle(rowIndex)}
            whileTap={reduceMotion ? {} : { scale: 0.98 }}
            transition={{ type: "spring", bounce: 0, duration: 0.3 }}
            className="flex w-full cursor-pointer items-center gap-4 rounded-[1.25rem] p-3.5 text-left transition-colors duration-200 hover:bg-neutral-950/4"
            aria-label={`Ligne ${row.line.shortName}, ${row.station}, ${level.label}. Toucher pour signaler`}
          >
            <span
              className="grid size-12 shrink-0 place-items-center rounded-[0.8rem] text-xl font-bold"
              style={{
                backgroundColor: row.line.color,
                color: row.line.textColor,
              }}
              aria-hidden="true"
            >
              {row.line.shortName}
            </span>
            <span className="min-w-0 flex-1">
              <span className="block truncate text-base font-semibold tracking-tight text-neutral-950">
                {row.station}
              </span>
              <motion.span
                key={level.label}
                className="block text-sm font-medium"
                style={{ color: level.color }}
                initial={reduceMotion ? false : { opacity: 0, y: 5 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ type: "spring", bounce: 0, duration: 0.35 }}
              >
                {level.label}
              </motion.span>
            </span>
            <span
              className="flex shrink-0 items-end gap-1.5 pr-1"
              aria-hidden="true"
            >
              {BAR_HEIGHTS.map((height, barIndex) => (
                <motion.span
                  key={height}
                  className={`inline-block w-2 origin-bottom rounded-full ${height}`}
                  animate={{
                    scaleY: barIndex <= (levels[rowIndex] ?? 0) ? 1 : 0.4,
                    backgroundColor:
                      barIndex <= (levels[rowIndex] ?? 0)
                        ? level.color
                        : "#e5e5e5",
                  }}
                  transition={
                    reduceMotion
                      ? { duration: 0 }
                      : {
                          scaleY: {
                            type: "spring",
                            bounce: 0.25,
                            duration: 0.45,
                            delay: barIndex * 0.05,
                          },
                          backgroundColor: {
                            duration: 0.3,
                            delay: barIndex * 0.05,
                          },
                        }
                  }
                />
              ))}
            </span>
          </motion.button>
        );
      })}
    </div>
  );
}
