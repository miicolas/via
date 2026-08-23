"use client";

import type { CallToAction } from "@/constants/types";
import { motion } from "motion/react";
import type { ReactNode } from "react";

interface ActionLinkProps extends CallToAction {
  readonly variant?: "primary" | "secondary";
  readonly className?: string;
}

const variants = {
  primary: "bg-foreground text-background hover:bg-foreground/90",
  secondary: "border border-border bg-frame text-foreground",
} as const;

export function ActionLink({
  label,
  href,
  variant = "primary",
  className = "",
}: ActionLinkProps): ReactNode {
  return (
    <motion.a
      href={href}
      whileHover={{ scale: 1.02 }}
      whileTap={{ scale: 0.98 }}
      className={`inline-flex items-center rounded-xl px-6 py-2.5 text-sm font-semibold transition-colors ${variants[variant]} ${className}`}
    >
      {label}
    </motion.a>
  );
}
