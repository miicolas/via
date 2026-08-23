"use client";

import type { JourneyMomentContent } from "@/constants/types";
import { MARKETING_EASE, useReducedMotion } from "@/lib/motion";
import { motion } from "motion/react";
import { useEffect, useState, type FocusEvent, type ReactNode } from "react";
import { JourneyMomentCopy } from "./journey-moment-copy";
import { JourneyMomentTabs } from "./journey-moment-tabs";
import { JourneyMomentVisual } from "./journey-moment-visual";

interface JourneyMomentsSectionProps {
  readonly title: string;
  readonly autoplayInterval: number;
  readonly moments: readonly JourneyMomentContent[];
}

export function JourneyMomentsSection({
  title,
  autoplayInterval,
  moments,
}: JourneyMomentsSectionProps): ReactNode {
  const reduceMotion = useReducedMotion();
  const [activeIndex, setActiveIndex] = useState(0);
  const [paused, setPaused] = useState(false);
  const activeMoment = moments[activeIndex] ?? moments[0];

  useEffect(() => {
    if (paused || reduceMotion || moments.length < 2) return;

    const timer = window.setTimeout(() => {
      setActiveIndex((current) => (current + 1) % moments.length);
    }, autoplayInterval);

    return () => window.clearTimeout(timer);
  }, [activeIndex, autoplayInterval, moments.length, paused, reduceMotion]);

  useEffect(() => {
    function updateVisibility(): void {
      setPaused(document.hidden);
    }

    document.addEventListener("visibilitychange", updateVisibility);
    return () =>
      document.removeEventListener("visibilitychange", updateVisibility);
  }, []);

  function resumeAfterFocus(event: FocusEvent<HTMLElement>): void {
    if (!event.currentTarget.contains(event.relatedTarget)) setPaused(false);
  }

  if (!activeMoment) return null;

  return (
    <section
      className="w-full border-y border-accent/15 bg-frame px-6 py-28 sm:py-32"
      onPointerEnter={() => setPaused(true)}
      onPointerLeave={() => setPaused(false)}
      onFocusCapture={() => setPaused(true)}
      onBlurCapture={resumeAfterFocus}
    >
      <div className="mx-auto max-w-5xl">
        <motion.h2
          initial={reduceMotion ? false : { opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-50px" }}
          transition={
            reduceMotion
              ? { duration: 0 }
              : { duration: 0.6, ease: MARKETING_EASE }
          }
          className="mb-14 text-4xl leading-[1.1] font-medium tracking-[-0.02em] text-balance text-neutral-900 sm:text-5xl lg:mb-20 lg:text-6xl dark:text-neutral-50"
        >
          {title}
        </motion.h2>
        <div className="grid items-center gap-10 lg:grid-cols-[1fr_1.1fr] lg:gap-16">
          <div>
            <JourneyMomentTabs
              moments={moments}
              activeIndex={activeIndex}
              autoplayInterval={autoplayInterval}
              paused={paused}
              onSelect={setActiveIndex}
            />
            <JourneyMomentCopy
              moment={activeMoment}
              activeIndex={activeIndex}
              paused={paused}
            />
          </div>
          <JourneyMomentVisual
            moment={activeMoment}
            activeIndex={activeIndex}
          />
        </div>
      </div>
    </section>
  );
}
