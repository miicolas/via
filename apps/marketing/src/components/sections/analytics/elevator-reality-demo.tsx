"use client";

import { ElevatorGlyph } from "@/components/ui/elevator-glyph";
import { TransitText } from "@/components/ui/transit-text";
import type { AnalyticsContent } from "@/constants/analytics-page";
import { useReducedMotion } from "@/lib/motion";
import { AnimatePresence, motion } from "motion/react";
import { useState, type ReactNode } from "react";

const THUMB_SPRING = { type: "spring", bounce: 0, duration: 0.4 } as const;
const PANEL_SPRING = { type: "spring", bounce: 0.18, duration: 0.5 } as const;

const statusStyle = {
  available: {
    dot: "bg-[#20bd57]",
    text: "text-[#17a34a]",
    glyph: "bg-[#20bd57]/14 text-[#17a34a]",
  },
  notavailable: {
    dot: "bg-[#ff453a]",
    text: "text-[#d92c20]",
    glyph: "bg-[#ff453a]/14 text-[#d92c20]",
  },
} as const;

export function ElevatorRealityDemo({
  content,
}: {
  readonly content: AnalyticsContent["elevators"]["live"];
}): ReactNode {
  const reduceMotion = useReducedMotion();
  const [modeIndex, setModeIndex] = useState(0);
  const live = modeIndex === 1;

  return (
    <div className="rounded-[1.75rem] border border-black/8 bg-white/94 p-4 shadow-[0_24px_70px_rgba(0,0,0,0.14)]">
      <div
        className="flex rounded-full bg-neutral-100 p-1 text-sm font-semibold"
        role="group"
        aria-label="Lecture des ascenseurs"
      >
        {content.modes.map((mode, index) => (
          <motion.button
            key={mode}
            type="button"
            onPointerDown={() => setModeIndex(index)}
            whileTap={reduceMotion ? {} : { scale: 0.96 }}
            className="relative flex-1 cursor-pointer px-3 py-2 text-center"
            aria-pressed={index === modeIndex}
          >
            {index === modeIndex && (
              <motion.span
                layoutId="elevator-reality-thumb"
                className="absolute inset-0 rounded-full bg-white shadow-sm"
                transition={reduceMotion ? { duration: 0 } : THUMB_SPRING}
              />
            )}
            <span
              className={`relative transition-colors duration-300 ${index === modeIndex ? "text-neutral-950" : "text-neutral-500"}`}
            >
              {mode}
            </span>
          </motion.button>
        ))}
      </div>

      <div className="mt-3">
        <AnimatePresence mode="wait" initial={false}>
          {live ? (
            <motion.div
              key="live"
              initial={
                reduceMotion
                  ? { opacity: 0 }
                  : { opacity: 0, y: 10, filter: "blur(8px)" }
              }
              animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
              exit={
                reduceMotion
                  ? { opacity: 0 }
                  : { opacity: 0, y: -8, filter: "blur(8px)" }
              }
              transition={reduceMotion ? { duration: 0 } : PANEL_SPRING}
            >
              <p className="px-3 pt-3 pb-1 text-xs font-medium text-neutral-500">
                <TransitText>{content.station}</TransitText> ·{" "}
                {content.elevators.length} ascenseurs
              </p>
              <ul>
                {content.elevators.map((elevator) => {
                  const style = statusStyle[elevator.status];

                  return (
                    <li
                      key={elevator.id}
                      className="flex items-center gap-3 rounded-2xl p-3"
                    >
                      <span
                        className={`grid size-10 shrink-0 place-items-center rounded-full ${style.glyph}`}
                        aria-hidden="true"
                      >
                        <ElevatorGlyph className="size-5" strokeWidth={1.9} />
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-sm font-semibold tracking-tight text-neutral-950">
                          {elevator.path}
                        </span>
                        <span className="block truncate text-xs text-neutral-500">
                          {elevator.detail}
                        </span>
                      </span>
                      <span
                        className={`flex shrink-0 items-center gap-1.5 text-xs font-semibold ${style.text}`}
                      >
                        <span
                          className={`size-2 rounded-full ${style.dot}`}
                          aria-hidden="true"
                        />
                        {content.statusLabels[elevator.status]}
                      </span>
                    </li>
                  );
                })}
              </ul>
            </motion.div>
          ) : (
            <motion.div
              key="quarter"
              initial={
                reduceMotion
                  ? { opacity: 0 }
                  : { opacity: 0, y: 10, filter: "blur(8px)" }
              }
              animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
              exit={
                reduceMotion
                  ? { opacity: 0 }
                  : { opacity: 0, y: -8, filter: "blur(8px)" }
              }
              transition={reduceMotion ? { duration: 0 } : PANEL_SPRING}
              className="px-3 py-6 text-center"
            >
              <p className="text-5xl leading-none font-medium tracking-tight text-neutral-950 tabular-nums">
                {content.quarter.value}
              </p>
              <p className="mt-3 text-sm font-medium text-neutral-600">
                {content.quarter.label}
              </p>
              <p className="mt-1 text-xs text-neutral-400">
                <TransitText>{content.quarter.detail}</TransitText>
              </p>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
