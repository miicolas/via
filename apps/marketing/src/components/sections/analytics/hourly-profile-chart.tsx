"use client";

import type { HourlyShare } from "@/constants/analytics-data";
import { useReducedMotion } from "@/lib/motion";
import { motion, useInView } from "motion/react";
import { useRef, type KeyboardEvent, type ReactNode } from "react";

const AXIS_HOURS: readonly number[] = [0, 6, 12, 18];
/** Une heure sans validation garde un filet visible plutôt que de disparaître. */
const MIN_BAR_SCALE = 0.014;

interface HourlyProfileChartProps {
  readonly profile: readonly HourlyShare[];
  readonly selectedHour: number;
  readonly onSelect: (hour: number) => void;
  readonly label: string;
}

export function HourlyProfileChart({
  profile,
  selectedHour,
  onSelect,
  label,
}: HourlyProfileChartProps): ReactNode {
  const reduceMotion = useReducedMotion();
  const trackRef = useRef<HTMLDivElement>(null);
  const inView = useInView(trackRef, { once: true, margin: "-60px" });
  const barRefs = useRef<Array<HTMLButtonElement | null>>([]);
  const peak = Math.max(...profile.map((entry) => entry.share));

  function moveSelection(
    event: KeyboardEvent<HTMLButtonElement>,
    index: number,
  ): void {
    let nextIndex: number | undefined;

    switch (event.key) {
      case "ArrowRight":
      case "ArrowUp":
        nextIndex = (index + 1) % profile.length;
        break;
      case "ArrowLeft":
      case "ArrowDown":
        nextIndex = (index - 1 + profile.length) % profile.length;
        break;
      case "Home":
        nextIndex = 0;
        break;
      case "End":
        nextIndex = profile.length - 1;
        break;
    }

    if (nextIndex === undefined) return;

    event.preventDefault();
    const nextHour = profile[nextIndex]?.hour;
    if (nextHour === undefined) return;
    onSelect(nextHour);
    barRefs.current[nextIndex]?.focus();
  }

  return (
    <div>
      <div
        ref={trackRef}
        className="flex h-44 items-end gap-[3px] sm:h-56"
        role="radiogroup"
        aria-label={label}
      >
        {profile.map((entry, index) => {
          const active = entry.hour === selectedHour;
          const target = Math.max(MIN_BAR_SCALE, entry.share / peak);

          return (
            <button
              ref={(node) => {
                barRefs.current[index] = node;
              }}
              key={entry.hour}
              type="button"
              role="radio"
              aria-checked={active}
              tabIndex={active ? 0 : -1}
              aria-label={`${entry.hour} h, ${entry.share.toLocaleString("fr-FR", { minimumFractionDigits: 2 })} % des validations`}
              onPointerDown={() => onSelect(entry.hour)}
              onKeyDown={(event) => moveSelection(event, index)}
              onFocus={() => onSelect(entry.hour)}
              className="focus-ring group flex h-full flex-1 cursor-pointer items-end rounded-md"
            >
              <motion.span
                className={`h-full w-full origin-bottom rounded-t-[4px] transition-colors duration-200 ${
                  active
                    ? "bg-accent"
                    : "bg-accent/22 group-hover:bg-accent/45 group-focus-visible:bg-accent/45 dark:bg-accent/40 dark:group-hover:bg-accent/65"
                }`}
                initial={reduceMotion ? false : { scaleY: MIN_BAR_SCALE }}
                animate={{
                  scaleY: reduceMotion || inView ? target : MIN_BAR_SCALE,
                }}
                transition={
                  reduceMotion
                    ? { duration: 0 }
                    : {
                        type: "spring",
                        bounce: 0.2,
                        duration: 0.7,
                        delay: index * 0.016,
                      }
                }
                aria-hidden="true"
              />
            </button>
          );
        })}
      </div>

      <div className="mt-3 flex gap-[3px]" aria-hidden="true">
        {profile.map((entry) => (
          <span
            key={entry.hour}
            className="flex-1 text-center text-[10px] whitespace-nowrap text-card-foreground-muted"
          >
            {AXIS_HOURS.includes(entry.hour) ? `${entry.hour} h` : ""}
          </span>
        ))}
      </div>
    </div>
  );
}
