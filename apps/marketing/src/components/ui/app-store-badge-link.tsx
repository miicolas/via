"use client";

import type { CallToAction } from "@/constants/types";
import { motion } from "motion/react";
import Image from "next/image";
import type { ReactNode } from "react";

interface AppStoreBadgeLinkProps extends CallToAction {
  readonly appearance?: "black" | "white";
}

export function AppStoreBadgeLink({
  label,
  href,
  appearance = "black",
}: AppStoreBadgeLinkProps): ReactNode {
  const assetVersion = appearance === "black" ? "100517" : "100217";

  return (
    <motion.a
      href={href}
      aria-label={label}
      whileHover={{ scale: 1.02 }}
      whileTap={{ scale: 0.98 }}
      className="focus-ring inline-flex min-h-11 items-center rounded-lg"
    >
      <Image
        src={`/app-store-badge-${appearance}.svg?v=${assetVersion}`}
        alt=""
        width={190}
        height={60}
        className="h-14 w-auto"
        unoptimized
        priority
      />
    </motion.a>
  );
}
