import { Clock3, Copy, Check, ArrowRight } from "lucide-react";
import { motion } from "motion/react";
import type { ReactNode } from "react";

import { marketingMedia } from "@/constants/media";
import {
  fadeInScale,
  fadeInUp,
  MARKETING_EASE,
  useReducedMotion,
} from "@/lib/motion";
import { cn } from "@/lib/utils";
import { formatDuration } from "@/lib/journey-share";
import { journeyStatusAppearances, type Journey } from "../journey-share-types";
import { formatJourneyDay } from "../lib/format-journey-day";
import { formatJourneyTime } from "../lib/format-journey-time";
import { JourneyMetric } from "./journey-metric";
import { RouteEndpoint } from "./route-endpoint";

export function JourneyShareHero({
  journey,
  origin,
  destination,
  locale,
  timeZone,
  copied,
  onCopy,
}: {
  readonly journey: Journey;
  readonly origin: string;
  readonly destination: string;
  readonly locale: string;
  readonly timeZone: string;
  readonly copied: boolean;
  readonly onCopy: () => void;
}): ReactNode {
  const reduceMotion = useReducedMotion();
  const status = journeyStatusAppearances[journey.status];

  return (
    <section
      className="relative mx-2.5 overflow-hidden rounded-b-[3rem] pt-40 pb-20 text-black max-[850px]:mx-0 max-[850px]:rounded-b-[2.25rem] max-[850px]:pt-32 sm:pb-24"
      style={{ colorScheme: "light" }}
    >
      <div
        className="absolute inset-0 scale-105 bg-cover bg-center bg-no-repeat brightness-100 contrast-110 saturate-110"
        style={{
          backgroundImage:
            "linear-gradient(180deg,rgba(102,181,249,0.62),rgba(78,163,239,0.84)),url(" +
            marketingMedia.background.src +
            ")",
          backgroundBlendMode: "multiply, normal",
          backgroundPosition: marketingMedia.background.position,
        }}
        aria-hidden="true"
      />

      <motion.div
        className="relative mx-auto max-w-7xl px-6"
        initial={reduceMotion ? false : "hidden"}
        animate="visible"
        transition={{ staggerChildren: 0.12, delayChildren: 0.08 }}
      >
        <motion.div
          className="flex items-center justify-between gap-4"
          variants={fadeInUp}
          transition={{ duration: 0.8, ease: MARKETING_EASE }}
        >
          <span className="inline-flex items-center gap-1.5 rounded-xl border border-black/10 bg-white/92 py-1.5 pr-3 pl-4 text-sm font-medium shadow-sm backdrop-blur">
            Trajet partagé <span className="text-[#0066ff]">✦</span>
          </span>
          <button
            type="button"
            onClick={onCopy}
            className="focus-ring inline-flex min-h-11 items-center gap-2 rounded-xl bg-white/92 px-4 text-sm font-semibold shadow-sm transition-colors hover:bg-white"
            aria-label={copied ? "Lien copié" : "Copier le lien du trajet"}
          >
            {copied ? (
              <Check className="size-4 text-emerald-600" aria-hidden="true" />
            ) : (
              <Copy className="size-4" aria-hidden="true" />
            )}
            <span aria-live="polite">{copied ? "Copié" : "Copier"}</span>
          </button>
        </motion.div>

        <h1 className="mt-10 max-w-5xl text-6xl leading-[0.98] font-medium tracking-tight text-balance sm:text-7xl lg:text-8xl">
          <motion.span
            className="block"
            variants={fadeInUp}
            transition={{ duration: 0.8, ease: MARKETING_EASE }}
          >
            Votre trajet,
          </motion.span>
          <motion.span
            className="block font-serif text-[#0066ff] italic"
            variants={fadeInUp}
            transition={{ duration: 0.8, ease: MARKETING_EASE }}
          >
            en clair.
          </motion.span>
        </h1>

        <motion.p
          className="mt-6 max-w-2xl text-base leading-7 text-neutral-700 sm:text-lg"
          variants={fadeInUp}
          transition={{ duration: 0.8, ease: MARKETING_EASE }}
        >
          Horaires, correspondances et perturbations réunis dans le même fil, du
          départ à l’arrivée.
        </motion.p>

        <motion.div
          className="mt-10 rounded-[2.25rem] bg-white/94 p-5 shadow-[0_28px_90px_rgba(0,52,112,0.18)] backdrop-blur-xl sm:p-7 lg:p-8"
          variants={fadeInScale}
          transition={{ duration: 0.9, ease: MARKETING_EASE }}
        >
          <div className="grid items-center gap-5 sm:grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] sm:gap-8">
            <RouteEndpoint
              label="Départ"
              name={origin}
              time={formatJourneyTime(journey.departureAt, locale, timeZone)}
              tone="origin"
            />
            <ArrowRight
              className="mx-auto size-6 rotate-90 text-neutral-400 sm:rotate-0"
              aria-hidden="true"
            />
            <RouteEndpoint
              label="Arrivée"
              name={destination}
              time={formatJourneyTime(journey.arrivalAt, locale, timeZone)}
              tone="destination"
            />
          </div>

          <div className="mt-7 flex flex-col gap-6 border-t border-black/8 pt-6 xl:flex-row xl:items-center xl:justify-between">
            <div className="flex flex-wrap items-center gap-3 text-sm text-neutral-600">
              <span className="inline-flex items-center gap-2 font-medium">
                <Clock3 className="size-4" aria-hidden="true" />
                {formatJourneyDay(journey.departureAt, locale, timeZone)}
              </span>
              <span
                className={cn(
                  "inline-flex items-center gap-2 rounded-full px-3 py-1.5 text-xs font-semibold",
                  status.className,
                )}
              >
                <span
                  className={cn("size-1.5 rounded-full", status.dotClassName)}
                  aria-hidden="true"
                />
                {status.label}
              </span>
            </div>

            <div className="grid grid-cols-3 divide-x divide-black/10">
              <JourneyMetric
                label="Durée"
                value={formatDuration(journey.durationSeconds)}
              />
              <JourneyMetric
                label="Correspondances"
                value={String(journey.transferCount)}
              />
              <JourneyMetric
                label="À pied"
                value={formatDuration(journey.walkingDurationSeconds)}
              />
            </div>
          </div>
        </motion.div>
      </motion.div>
    </section>
  );
}
