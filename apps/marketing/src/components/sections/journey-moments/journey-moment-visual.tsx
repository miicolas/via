"use client";

import { AppleIntelligenceGlyph } from "@/components/ui/apple-intelligence-glyph";
import { LiveSignalSymbol } from "@/components/sections/features/live-signal-symbol";
import { LineBadge } from "@/components/ui/line-badge";
import { TransitText } from "@/components/ui/transit-text";
import { journeyMomentVisuals } from "@/constants/journey-moments";
import type { JourneyMomentContent } from "@/constants/types";
import { useReducedMotion } from "@/lib/motion";
import { TriangleAlert } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import type { ReactNode } from "react";

function SearchVignette({
  reduceMotion,
}: {
  readonly reduceMotion: boolean;
}): ReactNode {
  const visual = journeyMomentVisuals.search;

  return (
    <div className="flex flex-col gap-3">
      <div className="rounded-full bg-gradient-to-r from-indigo-500 via-purple-500 to-orange-400 p-[1.5px] shadow-[0_16px_40px_rgba(124,58,237,0.22)]">
        <span className="flex items-center gap-2.5 rounded-full bg-white/96 py-3 pr-5 pl-3.5">
          <AppleIntelligenceGlyph
            className="size-5 shrink-0 text-purple-600"
            strokeWidth={1.8}
          />
          <span className="min-w-0 truncate text-sm font-medium text-neutral-950">
            {visual.prompt}
            <motion.span
              className="ml-px inline-block h-4 w-px translate-y-0.5 bg-neutral-950 align-baseline"
              animate={reduceMotion ? false : { opacity: [1, 0, 1] }}
              transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
            />
          </span>
        </span>
      </div>
      <div className="flex items-center gap-3 rounded-2xl border border-black/8 bg-white/96 p-3.5 shadow-[0_18px_50px_rgba(0,0,0,0.12)]">
        <LineBadge line={visual.result.line} />
        <span className="min-w-0 flex-1">
          <span className="block truncate text-sm font-semibold tracking-tight text-neutral-950">
            {visual.result.destination}
          </span>
          <span className="block truncate text-xs text-neutral-500">
            {visual.result.note}
          </span>
        </span>
      </div>
    </div>
  );
}

function JourneyVignette({
  reduceMotion,
}: {
  readonly reduceMotion: boolean;
}): ReactNode {
  const visual = journeyMomentVisuals.journey;

  return (
    <div className="rounded-[1.4rem] bg-neutral-950/92 p-4 text-white shadow-[0_18px_50px_rgba(0,0,0,0.35)] backdrop-blur-xl">
      <div className="flex items-center gap-3">
        <LineBadge
          line={visual.line}
          className="size-9 rounded-[0.6rem] text-base"
        />
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-semibold tracking-tight">
            {visual.destination}
          </p>
          <p className="truncate text-xs text-white/60">
            <TransitText>{visual.nextStop}</TransitText>
          </p>
        </div>
        <div className="flex shrink-0 items-baseline gap-1">
          <span className="text-2xl leading-none font-bold tabular-nums">
            {visual.minutes}
          </span>
          <span className="text-[0.62rem] font-semibold tracking-wide text-white/55">
            {visual.unit}
          </span>
        </div>
      </div>
      <div className="mt-3.5 h-1 overflow-hidden rounded-full bg-white/15">
        <motion.div
          className="h-full rounded-full"
          style={{ backgroundColor: visual.line.color }}
          initial={
            reduceMotion
              ? { width: `${visual.progress * 100}%` }
              : { width: "12%" }
          }
          animate={{ width: `${visual.progress * 100}%` }}
          transition={
            reduceMotion
              ? { duration: 0 }
              : { type: "spring", duration: 1.4, bounce: 0 }
          }
        />
      </div>
    </div>
  );
}

function DisruptionVignette(): ReactNode {
  const visual = journeyMomentVisuals.disruption;

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-3 rounded-2xl border border-black/8 bg-white/96 p-3.5 shadow-[0_18px_50px_rgba(0,0,0,0.12)]">
        <span className="grid size-10 shrink-0 place-items-center rounded-[0.7rem] bg-[#fdf1e2] text-[#e8590c]">
          <TriangleAlert className="size-5" strokeWidth={2.2} />
        </span>
        <span className="min-w-0 flex-1">
          <span className="block truncate text-sm font-semibold tracking-tight text-neutral-950">
            <TransitText>{visual.alert.title}</TransitText>
          </span>
          <span className="block truncate text-xs text-neutral-500">
            {visual.alert.note}
          </span>
        </span>
      </div>
      <div className="ml-8 flex items-center gap-3 rounded-2xl border border-black/8 bg-white/96 p-3.5 shadow-[0_18px_50px_rgba(0,0,0,0.1)]">
        <LineBadge line={visual.reroute.line} />
        <span className="min-w-0 flex-1">
          <span className="block truncate text-sm font-semibold tracking-tight text-neutral-950">
            {visual.reroute.title}
          </span>
          <span className="block truncate text-xs text-neutral-500">
            <TransitText>{visual.reroute.note}</TransitText>
          </span>
        </span>
      </div>
    </div>
  );
}

function StationVignette(): ReactNode {
  const visual = journeyMomentVisuals.station;

  return (
    <div className="rounded-[1.75rem] border border-black/8 bg-white/94 p-3 shadow-[0_24px_70px_rgba(0,0,0,0.14)] backdrop-blur-xl">
      <div className="flex items-center gap-2 px-2 pt-1.5 pb-2.5">
        <p className="min-w-0 flex-1 truncate text-base font-semibold tracking-tight text-neutral-950">
          <TransitText>{visual.name}</TransitText>
          <span className="ml-2 text-xs font-medium text-neutral-500">
            {visual.distance}
          </span>
        </p>
        <span className="shrink-0 text-[#20bd57]">
          <LiveSignalSymbol />
        </span>
      </div>
      {visual.rows.map((row) => (
        <div
          key={row.destination}
          className="flex items-center gap-3 rounded-[1.25rem] p-2.5"
        >
          <LineBadge
            line={row.line}
            className="size-10 rounded-[0.7rem] border border-white/65 text-lg shadow-sm"
          />
          <span className="min-w-0 flex-1 truncate text-sm font-semibold tracking-tight text-neutral-950">
            {row.destination}
          </span>
          <span className="flex shrink-0 items-baseline gap-1 rounded-full bg-[#eaf8ed] px-3 py-1.5">
            <span className="text-lg leading-none font-bold text-neutral-950 tabular-nums">
              {row.minutes}
            </span>
            <span className="text-[0.62rem] font-semibold tracking-wide text-neutral-500">
              {visual.unit}
            </span>
          </span>
        </div>
      ))}
    </div>
  );
}

function Vignette({
  icon,
  reduceMotion,
}: {
  readonly icon: JourneyMomentContent["icon"];
  readonly reduceMotion: boolean;
}): ReactNode {
  switch (icon) {
    case "search":
      return <SearchVignette reduceMotion={reduceMotion} />;
    case "journey":
      return <JourneyVignette reduceMotion={reduceMotion} />;
    case "disruption":
      return <DisruptionVignette />;
    case "station":
      return <StationVignette />;
  }
}

export function JourneyMomentVisual({
  moment,
  activeIndex,
}: {
  readonly moment: JourneyMomentContent;
  readonly activeIndex: number;
}): ReactNode {
  const reduceMotion = useReducedMotion();

  return (
    <div className="grid min-h-[20rem] items-center justify-items-center overflow-hidden rounded-4xl bg-card-secondary p-6 sm:min-h-[24rem] sm:p-10">
      <AnimatePresence initial={false}>
        <motion.div
          key={activeIndex}
          className="col-start-1 row-start-1 w-full max-w-sm"
          initial={
            reduceMotion
              ? { opacity: 0 }
              : { opacity: 0, scale: 0.94, filter: "blur(6px)" }
          }
          animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
          exit={
            reduceMotion
              ? { opacity: 0 }
              : { opacity: 0, scale: 0.94, filter: "blur(6px)" }
          }
          transition={
            reduceMotion
              ? { duration: 0 }
              : { duration: 0.45, ease: [0.23, 1, 0.32, 1] }
          }
        >
          <div aria-hidden="true">
            <Vignette icon={moment.icon} reduceMotion={reduceMotion} />
          </div>
          <p className="mt-7 text-center text-xs font-medium text-card-foreground-muted">
            {moment.detail}
          </p>
        </motion.div>
      </AnimatePresence>
    </div>
  );
}
