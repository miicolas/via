"use client";

import type { LogoAsset } from "@/constants/types";
import { MARKETING_EASE } from "@/lib/motion";
import { LogoLoop, type LogoLoopItem } from "@/components/ui/logo-loop";
import { motion } from "motion/react";
import Image from "next/image";
import type { ReactNode } from "react";

export function HeroLogoLoop({
  logos,
}: {
  readonly logos: readonly LogoAsset[];
}): ReactNode {
  const items: LogoLoopItem[] = logos.map((logo) => ({
    node: (
      <Image
        src={logo.src}
        alt={logo.name}
        width={120}
        height={32}
        className="h-[1em] w-auto"
      />
    ),
  }));

  return (
    <motion.div
      className="pt-24 pb-12"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.8, delay: 1, ease: MARKETING_EASE }}
    >
      <LogoLoop logos={items} speed={60} logoHeight={42} gap={124} />
    </motion.div>
  );
}
