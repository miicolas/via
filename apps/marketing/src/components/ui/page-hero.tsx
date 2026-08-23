"use client";

import { fadeInScale, fadeInUp, MARKETING_EASE } from "@/lib/motion";
import { motion } from "motion/react";
import type { ReactNode } from "react";

export interface PageHeadline {
  readonly line1: string;
  readonly line2: string;
  readonly accent: string;
}

interface PageHeroProps {
  readonly badge: string;
  readonly headline: PageHeadline;
  readonly description: string;
  /** La rangée d’actions, propre à chaque page. */
  readonly children: ReactNode;
}

/**
 * Le même en-tête que la page d’accueil — pastille, titre en deux lignes avec
 * son mot en italique, chapô — pour les pages qui n’ont pas de photo de fond.
 */
export function PageHero({
  badge,
  headline,
  description,
  children,
}: PageHeroProps): ReactNode {
  return (
    <section className="w-full px-6 pt-40 pb-20 sm:pt-48 sm:pb-28">
      <motion.div
        className="mx-auto flex max-w-4xl flex-col items-center text-center max-[850px]:items-start max-[850px]:text-left"
        initial="hidden"
        animate="visible"
        transition={{ staggerChildren: 0.15, delayChildren: 0.1 }}
      >
        <motion.div
          className="mb-6 inline-flex items-center gap-1.5 rounded-xl border border-foreground/10 bg-frame py-1.5 pr-3 pl-4 text-sm font-medium text-foreground"
          variants={fadeInUp}
          transition={{ duration: 0.8, ease: MARKETING_EASE }}
        >
          {badge}
          <span className="text-accent">✦</span>
        </motion.div>

        <h1 className="mb-6 text-7xl leading-[1.05] font-medium tracking-tight text-balance text-foreground max-[850px]:text-5xl">
          <motion.span
            className="block"
            variants={fadeInUp}
            transition={{ duration: 0.8, ease: MARKETING_EASE }}
          >
            {headline.line1}
          </motion.span>
          <motion.span
            className="block"
            variants={fadeInUp}
            transition={{ duration: 0.8, ease: MARKETING_EASE }}
          >
            {headline.line2}{" "}
            <span className="font-serif text-accent italic">
              {headline.accent}
            </span>
          </motion.span>
        </h1>

        <motion.p
          className="mb-9 max-w-2xl text-lg leading-8 text-muted-foreground"
          variants={fadeInUp}
          transition={{ duration: 0.8, ease: MARKETING_EASE }}
        >
          {description}
        </motion.p>

        <motion.div
          className="flex flex-wrap items-center justify-center gap-5 max-[850px]:justify-start"
          variants={fadeInScale}
          transition={{ duration: 0.8, ease: MARKETING_EASE }}
        >
          {children}
        </motion.div>
      </motion.div>
    </section>
  );
}
