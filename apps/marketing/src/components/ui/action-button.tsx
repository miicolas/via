"use client";

import { motion, type HTMLMotionProps } from "motion/react";
import type { ReactNode } from "react";

interface ActionButtonProps extends Omit<
  HTMLMotionProps<"button">,
  "children"
> {
  readonly children: ReactNode;
  readonly variant?: "primary" | "muted";
}

export function ActionButton({
  children,
  variant = "primary",
  className = "",
  type = "button",
  ...props
}: ActionButtonProps): ReactNode {
  const colors =
    variant === "primary"
      ? "bg-foreground text-background hover:bg-foreground/90"
      : "bg-muted text-foreground hover:bg-muted/80";

  return (
    <motion.button
      {...props}
      type={type}
      whileHover={{ scale: 1.02 }}
      whileTap={{ scale: 0.98 }}
      className={`rounded-xl text-sm font-semibold transition-colors ${colors} ${className}`}
    >
      {children}
    </motion.button>
  );
}
