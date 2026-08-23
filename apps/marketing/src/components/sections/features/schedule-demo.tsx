"use client";

import type { FeaturesContent } from "@/constants/features";
import {
  animate,
  motion,
  useMotionValue,
  useMotionValueEvent,
  useReducedMotion,
} from "motion/react";
import { useState, type ReactNode } from "react";

const ITEM_HEIGHT = 40;
const WHEEL_HEIGHT = 120;
const WHEEL_MASK =
  "linear-gradient(to bottom, transparent, black 28%, black 72%, transparent)";

export function ScheduleDemo({
  content,
}: {
  readonly content: FeaturesContent["highlights"]["schedule"];
}): ReactNode {
  const reduceMotion = useReducedMotion();
  const [optionIndex, setOptionIndex] = useState(0);
  const [timeIndex, setTimeIndex] = useState(2);
  const y = useMotionValue(-2 * ITEM_HEIGHT);
  const minY = -(content.times.length - 1) * ITEM_HEIGHT;

  useMotionValueEvent(y, "change", (value) => {
    const index = Math.min(
      content.times.length - 1,
      Math.max(0, Math.round(-value / ITEM_HEIGHT)),
    );
    setTimeIndex(index);
  });

  const snapTo = (index: number): void => {
    animate(
      y,
      -index * ITEM_HEIGHT,
      reduceMotion
        ? { duration: 0 }
        : { type: "spring", bounce: 0, duration: 0.4 },
    );
  };

  return (
    <div className="rounded-[1.75rem] border border-black/8 bg-white/94 p-4 shadow-[0_24px_70px_rgba(0,0,0,0.14)]">
      <div
        className="flex rounded-full bg-neutral-100 p-1 text-sm font-semibold"
        role="group"
        aria-label="Choix de l’horaire"
      >
        {content.options.map((option, index) => (
          <motion.button
            key={option}
            type="button"
            onClick={() => setOptionIndex(index)}
            whileTap={reduceMotion ? {} : { scale: 0.96 }}
            className="relative flex-1 cursor-pointer px-3 py-2 text-center"
            aria-pressed={index === optionIndex}
          >
            {index === optionIndex && (
              <motion.span
                layoutId="schedule-demo-thumb"
                className="absolute inset-0 rounded-full bg-white shadow-sm"
                transition={
                  reduceMotion
                    ? { duration: 0 }
                    : { type: "spring", bounce: 0, duration: 0.4 }
                }
              />
            )}
            <span
              className={`relative transition-colors duration-300 ${index === optionIndex ? "text-neutral-950" : "text-neutral-500"}`}
            >
              {option}
            </span>
          </motion.button>
        ))}
      </div>
      <div
        className="relative mt-4 overflow-hidden"
        style={{
          height: WHEEL_HEIGHT,
          maskImage: WHEEL_MASK,
          WebkitMaskImage: WHEEL_MASK,
        }}
        aria-label={`Heure choisie : ${content.times[timeIndex]}`}
      >
        <div
          className="absolute inset-x-3 top-1/2 h-10 -translate-y-1/2 rounded-xl bg-neutral-100"
          aria-hidden="true"
        />
        <div
          className="absolute inset-x-0"
          style={{ top: (WHEEL_HEIGHT - ITEM_HEIGHT) / 2 }}
        >
          <motion.div
            drag="y"
            style={{ y }}
            dragConstraints={{ top: minY, bottom: 0 }}
            dragElastic={0.15}
            dragTransition={{
              power: 0.25,
              timeConstant: 180,
              modifyTarget: (target) =>
                Math.min(
                  0,
                  Math.max(minY, Math.round(target / ITEM_HEIGHT) * ITEM_HEIGHT),
                ),
            }}
            className="cursor-grab active:cursor-grabbing"
          >
            {content.times.map((time, index) => (
              <button
                key={time}
                type="button"
                onClick={() => snapTo(index)}
                className={`grid h-10 w-full cursor-pointer place-items-center text-xl font-bold tabular-nums transition-colors duration-200 ${index === timeIndex ? "text-neutral-950" : "text-neutral-400"}`}
                aria-label={`Choisir ${time}`}
              >
                {time}
              </button>
            ))}
          </motion.div>
        </div>
      </div>
    </div>
  );
}
