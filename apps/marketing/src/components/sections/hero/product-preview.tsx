"use client";

import type { PageContent } from "@/constants/page";
import { ProductScreenshot } from "@/components/ui/product-screenshot";
import { departurePreview } from "@/constants/departures";
import { MARKETING_EASE } from "@/lib/motion";
import { motion } from "motion/react";
import type { ReactNode } from "react";
import { LiveDepartureZoom } from "../features/live-departure-zoom";

export function ProductPreview({
  preview,
}: {
  readonly preview: PageContent["hero"]["preview"];
}): ReactNode {
  return (
    <motion.div
      className="relative mt-24 px-6 max-[850px]:mt-10"
      initial={{ opacity: 0, y: 40 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 1, delay: 0.6, ease: MARKETING_EASE }}
    >
      <div className="relative mx-auto grid max-w-5xl items-center gap-8 overflow-hidden rounded-[2.5rem] border border-white/55 bg-white/52 p-6 shadow-2xl/10 backdrop-blur-xl md:grid-cols-[0.72fr_1.28fr] md:gap-12 md:p-10">
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_20%_20%,rgba(24,114,247,0.32),transparent_38%)]" />
        <ProductScreenshot
          asset={preview}
          className="relative mx-auto w-full max-w-72 rotate-[-2deg] transition-transform duration-700 hover:rotate-0"
          priority
          sizes="(max-width: 768px) 70vw, 288px"
        />
        <div className="relative">
          <p className="mb-3 text-xs font-semibold tracking-[0.18em] text-neutral-500 uppercase">
            {departurePreview.eyebrow}
          </p>
          <h2 className="max-w-lg text-3xl leading-tight font-medium tracking-tight text-neutral-950 md:text-5xl">
            {departurePreview.title}
          </h2>
          <p className="mt-4 max-w-md text-sm leading-relaxed text-neutral-600 md:text-base">
            {departurePreview.description}
          </p>
          <LiveDepartureZoom
            departure={departurePreview}
            className="mt-8 md:-ml-20"
          />
        </div>
      </div>
    </motion.div>
  );
}
