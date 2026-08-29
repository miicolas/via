"use client";

import type { PageContent } from "@/constants/page";
import { fadeInScale, fadeInUp, MARKETING_EASE } from "@/lib/motion";
import { LaunchAction } from "@/components/ui/launch-action";
import { motion } from "motion/react";
import type { ReactNode } from "react";

export function HeroCopy({
  content,
}: {
  readonly content: PageContent["hero"];
}): ReactNode {
  return (
    <motion.div
      className="flex max-w-4xl flex-col items-center text-center max-[850px]:w-full max-[850px]:items-start max-[850px]:text-left"
      initial="hidden"
      animate="visible"
      transition={{ staggerChildren: 0.15, delayChildren: 0.2 }}
    >
      <motion.div
        className="mb-6 inline-flex items-center gap-1.5 rounded-xl border border-black/10 bg-white py-1.5 pr-3 pl-4 text-sm font-medium text-black"
        variants={fadeInUp}
        transition={{ duration: 0.8, ease: MARKETING_EASE }}
      >
        {content.badge}
        <span className="text-accent">✦</span>
      </motion.div>

      <h1 className="mb-6 text-8xl leading-[1.1] font-medium tracking-tight text-black max-[850px]:text-5xl">
        <motion.span
          className="block"
          variants={fadeInUp}
          transition={{ duration: 0.8, ease: MARKETING_EASE }}
        >
          {content.headline.line1}
        </motion.span>
        <motion.span
          className="block"
          variants={fadeInUp}
          transition={{ duration: 0.8, ease: MARKETING_EASE }}
        >
          {content.headline.line2}{" "}
          <span className="font-serif text-accent italic">
            {content.headline.accent}
          </span>
        </motion.span>
      </h1>

      <motion.p
        className="mb-8 text-lg text-neutral-600"
        variants={fadeInUp}
        transition={{ duration: 0.8, ease: MARKETING_EASE }}
      >
        {content.description}
      </motion.p>

      <motion.div
        variants={fadeInScale}
        transition={{ duration: 0.8, ease: MARKETING_EASE }}
      >
        <LaunchAction configuration={content.action} mode="badge" appearance="black" />
      </motion.div>
    </motion.div>
  );
}
