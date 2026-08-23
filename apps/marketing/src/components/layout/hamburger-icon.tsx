"use client";

import { MARKETING_EASE } from "@/lib/motion";
import { motion } from "motion/react";
import type { ReactNode } from "react";

export function HamburgerIcon({ open }: { readonly open: boolean }): ReactNode {
  return (
    <span className="relative flex h-4 w-8 cursor-pointer flex-col justify-between">
      <motion.span
        className="block h-0.5 w-full origin-center rounded-full bg-foreground"
        animate={open ? { rotate: 45, y: 4.5 } : { rotate: 0, y: 0 }}
        transition={{ duration: 0.25, ease: MARKETING_EASE }}
      />
      <motion.span
        className="block h-0.5 w-full origin-center rounded-full bg-foreground"
        animate={open ? { rotate: -45, y: -9.5 } : { rotate: 0, y: 0 }}
        transition={{ duration: 0.25, ease: MARKETING_EASE }}
      />
    </span>
  );
}
