"use client";

import { MARKETING_EASE } from "@/lib/motion";
import { motion } from "motion/react";
import type { ReactNode } from "react";

interface RevealProps {
  readonly children: ReactNode;
  readonly className?: string;
  readonly delay?: number;
  readonly distance?: number;
  readonly duration?: number;
  readonly margin?: `${number}px`;
}

export function Reveal({
  children,
  className,
  delay = 0,
  distance = 20,
  duration = 0.6,
  margin = "-50px",
}: RevealProps): ReactNode {
  return (
    <motion.div
      initial={{ opacity: 0, y: distance }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin }}
      transition={{ duration, delay, ease: MARKETING_EASE }}
      className={className}
    >
      {children}
    </motion.div>
  );
}
