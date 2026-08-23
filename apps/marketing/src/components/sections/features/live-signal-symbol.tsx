"use client";

import { motion, useReducedMotion } from "motion/react";
import type { ReactNode } from "react";

const WAVE_TRANSITION = {
  duration: 1.8,
  ease: "easeInOut",
  repeat: Infinity,
} as const;

export function LiveSignalSymbol(): ReactNode {
  const reduceMotion = useReducedMotion();

  return (
    <motion.svg
      aria-hidden="true"
      viewBox="0 0 24 24"
      className="size-5 shrink-0"
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeWidth="2.4"
    >
      <motion.circle
        cx="4.25"
        cy="19.75"
        r="1.75"
        fill="currentColor"
        stroke="none"
        animate={reduceMotion ? false : { opacity: [0.65, 1, 0.65] }}
        transition={WAVE_TRANSITION}
      />
      <motion.path
        d="M4.5 14.5a5 5 0 0 1 5 5"
        animate={reduceMotion ? false : { opacity: [0.25, 1, 0.25] }}
        transition={{ ...WAVE_TRANSITION, delay: 0.1 }}
      />
      <motion.path
        d="M4.5 9.25A10.25 10.25 0 0 1 14.75 19.5"
        animate={reduceMotion ? false : { opacity: [0.2, 1, 0.2] }}
        transition={{ ...WAVE_TRANSITION, delay: 0.3 }}
      />
      <motion.path
        d="M4.5 4A15.5 15.5 0 0 1 20 19.5"
        animate={reduceMotion ? false : { opacity: [0.15, 1, 0.15] }}
        transition={{ ...WAVE_TRANSITION, delay: 0.5 }}
      />
    </motion.svg>
  );
}
