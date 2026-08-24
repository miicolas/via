"use client";

import { Reveal } from "@/components/ui/reveal";
import { SectionHeading } from "@/components/ui/section-heading";
import { TransitText } from "@/components/ui/transit-text";
import { gareDuNordHourlyProfile, peakHour } from "@/constants/analytics-data";
import type { AnalyticsContent } from "@/constants/analytics-page";
import { useReducedMotion } from "@/lib/motion";
import { motion } from "motion/react";
import { useState, type ReactNode } from "react";
import { HourlyProfileChart } from "./hourly-profile-chart";

/** La lecture suit le doigt : elle apparaît tout de suite, puis se pose. */
const READOUT_SPRING = { type: "spring", bounce: 0, duration: 0.25 } as const;

function shareOf(hour: number): number {
  return (
    gareDuNordHourlyProfile.find((entry) => entry.hour === hour)?.share ?? 0
  );
}

function formatShare(share: number): string {
  return share.toLocaleString("fr-FR", { minimumFractionDigits: 2 });
}

function formatHourRange(hour: number): string {
  return `${hour} h – ${(hour + 1) % 24} h`;
}

export function PeakHoursSection({
  content,
}: {
  readonly content: AnalyticsContent["peak"];
}): ReactNode {
  const reduceMotion = useReducedMotion();
  const [selectedHour, setSelectedHour] = useState(peakHour);
  const share = shareOf(selectedHour);
  const peakShare = shareOf(peakHour);

  const comparison = ((): string => {
    if (selectedHour === peakHour) return content.peakLabel;
    if (share < 0.5) return content.emptyLabel;

    const ratio = peakShare / share;
    return `${ratio.toLocaleString("fr-FR", {
      minimumFractionDigits: 1,
      maximumFractionDigits: 1,
    })}× plus calme que la pointe de ${peakHour} h.`;
  })();

  return (
    <section className="w-full px-6 py-20 sm:py-28">
      <div className="mx-auto max-w-5xl">
        <SectionHeading
          eyebrow={content.eyebrow}
          title={content.title}
          description={content.description}
          width="wide"
        />

        <Reveal
          distance={30}
          duration={0.7}
          margin="-80px"
          className="grid gap-10 overflow-hidden rounded-4xl bg-card-secondary p-6 md:grid-cols-[0.8fr_1.2fr] md:items-center md:gap-12 md:p-10"
        >
          <div>
            <p className="text-sm font-medium text-card-foreground-muted">
              <TransitText>{content.station}</TransitText>
            </p>
            <p className="mt-0.5 text-xs text-card-foreground-muted/80">
              {content.dayType}
            </p>

            <div className="mt-6 min-h-32">
              <motion.div
                key={selectedHour}
                initial={reduceMotion ? false : { opacity: 0.35, y: 6 }}
                animate={{ opacity: 1, y: 0 }}
                transition={reduceMotion ? { duration: 0 } : READOUT_SPRING}
              >
                <p className="text-6xl leading-none font-medium tracking-tight text-card-foreground tabular-nums">
                  {formatShare(share)}
                  <span className="ml-1 text-3xl"> %</span>
                </p>
                <p className="mt-3 text-base text-card-foreground-muted">
                  {content.unit}, entre{" "}
                  <span className="font-semibold text-card-foreground">
                    {formatHourRange(selectedHour)}
                  </span>
                  .
                </p>
              </motion.div>
            </div>

            <div className="mt-2 min-h-11">
              <motion.p
                key={comparison}
                initial={reduceMotion ? false : { opacity: 0.35, scale: 0.98 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={reduceMotion ? { duration: 0 } : READOUT_SPRING}
                className="inline-flex rounded-full bg-accent/12 px-3.5 py-2 text-sm font-semibold text-accent"
              >
                {comparison}
              </motion.p>
            </div>
          </div>

          <div>
            <HourlyProfileChart
              profile={gareDuNordHourlyProfile}
              selectedHour={selectedHour}
              onSelect={setSelectedHour}
              label={`Répartition horaire des validations à ${content.station}`}
            />
            <p className="mt-5 border-t border-card-foreground/10 pt-4 text-xs text-card-foreground-muted">
              {content.footnote}
            </p>
          </div>
        </Reveal>

        <div className="mt-4 grid gap-4 sm:grid-cols-3">
          {content.facts.map((fact, index) => (
            <Reveal
              key={fact.value}
              distance={24}
              duration={0.6}
              delay={index * 0.08}
              margin="-60px"
              className="rounded-4xl bg-frame p-6"
            >
              <p className="text-3xl leading-none font-medium tracking-tight text-foreground tabular-nums">
                {fact.value}
              </p>
              <p className="mt-3 text-sm leading-6 text-muted-foreground">
                {fact.label}
              </p>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
