"use client";

import type { JourneyMomentContent } from "@/constants/types";
import { useReducedMotion } from "@/lib/motion";
import { AnimatePresence, motion } from "motion/react";
import type { ReactNode } from "react";

export function JourneyMomentCopy({
  moment,
  activeIndex,
  paused,
}: {
  readonly moment: JourneyMomentContent;
  readonly activeIndex: number;
  readonly paused: boolean;
}): ReactNode {
  const reduceMotion = useReducedMotion();

  return (
    <div
      className="mt-10 grid min-h-44 sm:min-h-40"
      id="journey-moment-panel"
      role="tabpanel"
      aria-labelledby={`journey-moment-tab-${activeIndex}`}
      aria-live={paused ? "polite" : "off"}
    >
      <AnimatePresence initial={false}>
        <motion.div
          key={activeIndex}
          className="col-start-1 row-start-1"
          initial={
            reduceMotion
              ? { opacity: 0 }
              : { opacity: 0, y: 12, filter: "blur(4px)" }
          }
          animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
          exit={
            reduceMotion
              ? { opacity: 0 }
              : { opacity: 0, y: -12, filter: "blur(4px)" }
          }
          transition={
            reduceMotion
              ? { duration: 0 }
              : { duration: 0.4, ease: [0.23, 1, 0.32, 1] }
          }
        >
          <p className="mb-3 text-sm font-medium tracking-[0.01em] text-accent">
            {moment.label}
          </p>
          <h3 className="mb-4 text-2xl leading-tight font-medium tracking-[-0.01em] text-neutral-950 sm:text-3xl dark:text-neutral-50">
            {moment.title}
          </h3>
          <p className="text-lg leading-relaxed text-neutral-700 sm:text-xl dark:text-neutral-300">
            {moment.description}
          </p>
        </motion.div>
      </AnimatePresence>
    </div>
  );
}
