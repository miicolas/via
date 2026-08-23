"use client";

import type { CallToAction, ProcessStepContent } from "@/constants/types";
import { ActionLink } from "@/components/ui/action-link";
import { motion, useScroll, useTransform } from "motion/react";
import { useRef, type ReactNode } from "react";
import { ProcessStep } from "./process-step";

interface ProcessSectionProps {
  readonly content: {
    readonly title: string;
    readonly descriptionStart: string;
    readonly descriptionHighlight: string;
    readonly descriptionEnd: string;
    readonly action: CallToAction;
  };
  readonly steps: readonly ProcessStepContent[];
}

export function ProcessSection({
  content,
  steps,
}: ProcessSectionProps): ReactNode {
  const containerRef = useRef<HTMLElement>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start 0.3", "end 0.7"],
  });
  const lineHeight = useTransform(scrollYProgress, [0, 1], ["0%", "100%"]);

  return (
    <section ref={containerRef} className="relative w-full bg-background">
      <div className="mx-auto grid max-w-5xl gap-12 px-6 py-20 sm:py-28 lg:grid-cols-2 lg:gap-20">
        <div className="lg:sticky lg:top-48 lg:h-fit lg:self-start">
          <h2 className="text-4xl font-semibold tracking-tight text-foreground sm:text-5xl lg:text-6xl">
            {content.title}
          </h2>
          <p className="mt-6 max-w-md text-lg leading-relaxed text-foreground/60">
            {content.descriptionStart}{" "}
            <span className="font-medium text-foreground">
              {content.descriptionHighlight}
            </span>
            {content.descriptionEnd}
          </p>
          <ActionLink {...content.action} className="mt-8 py-3" />
        </div>
        <div className="relative">
          <div
            className="absolute top-6 left-6 h-[calc(100%-6rem)] w-0.5 -translate-x-1/2 bg-foreground/10"
            aria-hidden="true"
          >
            <motion.div
              style={{ height: lineHeight, willChange: "height" }}
              className="w-full bg-accent"
            />
          </div>
          <ol className="relative m-0 list-none p-0">
            {steps.map((step, index) => (
              <li key={step.title}>
                <ProcessStep step={step} last={index === steps.length - 1} />
              </li>
            ))}
          </ol>
        </div>
      </div>
    </section>
  );
}
