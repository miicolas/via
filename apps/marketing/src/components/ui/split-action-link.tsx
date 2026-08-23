"use client";

import type { CallToAction } from "@/constants/types";
import { ArrowDownRight } from "lucide-react";
import { motion } from "motion/react";
import type { MouseEventHandler, ReactNode } from "react";

interface SplitActionLinkProps extends CallToAction {
  readonly mobileFullWidth?: boolean;
  readonly onClick?: MouseEventHandler<HTMLAnchorElement>;
  readonly tone?: "theme" | "dark";
}

export function SplitActionLink({
  label,
  href,
  mobileFullWidth = false,
  onClick,
  tone = "theme",
}: SplitActionLinkProps): ReactNode {
  const labelColors =
    tone === "dark" ? "bg-black text-white" : "bg-foreground text-background";

  return (
    <motion.a
      href={href}
      onClick={onClick}
      whileHover={{ scale: 1.02 }}
      whileTap={{ scale: 0.98 }}
      className={`group relative inline-flex items-center ${mobileFullWidth ? "max-[850px]:w-full" : ""}`}
    >
      <span
        className={`absolute inset-y-0 right-0 rounded-xl bg-accent ${mobileFullWidth ? "w-[calc(100%-2rem)] max-[850px]:w-full" : "w-[calc(100%-1.5rem)]"}`}
      />
      <span
        className={`relative z-10 rounded-xl font-medium ${labelColors} ${mobileFullWidth ? "px-6 py-3 max-[850px]:flex-1" : "px-5 py-3 text-sm"}`}
      >
        {label}
      </span>
      <span
        className={`relative -left-px z-10 flex items-center justify-center rounded-xl text-white ${mobileFullWidth ? "h-11 w-11" : "h-10 w-10"}`}
      >
        <ArrowDownRight
          className={`${mobileFullWidth ? "h-5 w-5" : "h-4 w-4"} transition-transform duration-300 group-hover:-rotate-45`}
          aria-hidden="true"
        />
      </span>
    </motion.a>
  );
}
