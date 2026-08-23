"use client";

import type { JourneyMomentContent } from "@/constants/types";
import { useReducedMotion } from "@/lib/motion";
import { AnimatePresence, motion } from "motion/react";
import { useRef, type KeyboardEvent, type ReactNode } from "react";
import { JourneyMomentIcon } from "./journey-moment-icon";

interface JourneyMomentTabsProps {
  readonly moments: readonly JourneyMomentContent[];
  readonly activeIndex: number;
  readonly autoplayInterval: number;
  readonly paused: boolean;
  readonly onSelect: (index: number) => void;
}

export function JourneyMomentTabs({
  moments,
  activeIndex,
  autoplayInterval,
  paused,
  onSelect,
}: JourneyMomentTabsProps): ReactNode {
  const reduceMotion = useReducedMotion();
  const buttonRefs = useRef<Array<HTMLButtonElement | null>>([]);

  function selectFromKeyboard(
    event: KeyboardEvent<HTMLButtonElement>,
    index: number,
  ): void {
    let nextIndex: number | undefined;

    switch (event.key) {
      case "ArrowRight":
        nextIndex = (index + 1) % moments.length;
        break;
      case "ArrowLeft":
        nextIndex = (index - 1 + moments.length) % moments.length;
        break;
      case "Home":
        nextIndex = 0;
        break;
      case "End":
        nextIndex = moments.length - 1;
        break;
    }

    if (nextIndex === undefined) return;

    event.preventDefault();
    onSelect(nextIndex);
    buttonRefs.current[nextIndex]?.focus();
  }

  const settleSpring = reduceMotion
    ? { duration: 0 }
    : ({ type: "spring", duration: 0.4, bounce: 0 } as const);

  return (
    <div
      className="flex items-center justify-start gap-4 lg:gap-6"
      role="tablist"
      aria-label="Fonctionnalités de Metyro"
    >
      {moments.map((moment, index) => {
        const active = activeIndex === index;
        const progressLength = 2 * Math.PI * 48;

        return (
          <motion.button
            ref={(node) => {
              buttonRefs.current[index] = node;
            }}
            key={moment.label}
            type="button"
            initial={reduceMotion ? false : { scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: active ? 1 : 0.52 }}
            whileTap={{ scale: reduceMotion ? 1 : 0.94 }}
            transition={settleSpring}
            className="focus-ring relative flex size-14 cursor-pointer items-center justify-center rounded-full sm:size-[4.5rem]"
            role="tab"
            id={`journey-moment-tab-${index}`}
            aria-controls="journey-moment-panel"
            aria-label={moment.label}
            aria-selected={active}
            tabIndex={active ? 0 : -1}
            onClick={() => onSelect(index)}
            onKeyDown={(event) => selectFromKeyboard(event, index)}
          >
            <motion.span
              animate={{ scale: active ? 1.08 : 0.92 }}
              transition={settleSpring}
              className="flex size-12 items-center justify-center rounded-full bg-neutral-200 text-neutral-700 transition-[background-color,color] duration-200 sm:size-16 dark:bg-neutral-800 dark:text-neutral-200"
              style={
                active ? { backgroundColor: moment.color, color: "white" } : {}
              }
            >
              <JourneyMomentIcon name={moment.icon} />
            </motion.span>
            <AnimatePresence>
              {active && (
                <motion.svg
                  key="ring"
                  className="pointer-events-none absolute -inset-1 size-[calc(100%+8px)] -rotate-90"
                  viewBox="0 0 100 100"
                  aria-hidden="true"
                  initial={reduceMotion ? false : { opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: reduceMotion ? 0 : 0.2 }}
                >
                  <circle
                    cx="50"
                    cy="50"
                    r="48"
                    fill="none"
                    stroke={moment.color}
                    strokeWidth="1.5"
                    opacity="0.2"
                  />
                  <AnimatePresence>
                    {!reduceMotion && !paused && (
                      <motion.circle
                        key={`progress-${activeIndex}`}
                        cx="50"
                        cy="50"
                        r="48"
                        fill="none"
                        stroke={moment.color}
                        strokeWidth="1.5"
                        strokeDasharray={progressLength}
                        initial={{ strokeDashoffset: progressLength }}
                        animate={{ strokeDashoffset: 0 }}
                        exit={{ opacity: 0 }}
                        transition={{
                          strokeDashoffset: {
                            duration: autoplayInterval / 1000,
                            ease: "linear",
                          },
                          opacity: { duration: 0.2 },
                        }}
                        strokeLinecap="round"
                      />
                    )}
                  </AnimatePresence>
                </motion.svg>
              )}
            </AnimatePresence>
          </motion.button>
        );
      })}
    </div>
  );
}
