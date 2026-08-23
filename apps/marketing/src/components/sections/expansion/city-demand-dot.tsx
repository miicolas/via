"use client";

import { expansionContent } from "@/constants/expansion";
import type { VotableCity } from "@/constants/cities";
import { projectOnFranceMap } from "@/lib/france-map";
import { useReducedMotion } from "@/lib/motion";
import { motion } from "motion/react";
import type { ReactNode } from "react";

interface CityDemandDotProps {
  readonly city: VotableCity;
  readonly votes: number;
  /** Share of the most-wanted city's score, between 0 and 1. It sets the size. */
  readonly weight: number;
  readonly leading: boolean;
  /** The handful of cities whose names are worth carrying at rest. */
  readonly named: boolean;
  readonly selected: boolean;
  readonly backed: boolean;
  readonly onSelect: (city: VotableCity, dot: HTMLButtonElement) => void;
}

/**
 * One city on the map: a target big enough for a thumb, a dot small enough to
 * read as a place. Both are sized as a share of the drawing, so a dot keeps its
 * proportions when small screens scale the map up.
 *
 * Demand is drawn twice — a core that barely grows, and a halo that grows a
 * lot. A dot that only swelled would stop reading as a place; the halo carries
 * the quantity and leaves the point where the city actually is.
 */
export function CityDemandDot({
  city,
  votes,
  weight,
  leading,
  named,
  selected,
  backed,
  onSelect,
}: CityDemandDotProps): ReactNode {
  const reducedMotion = useReducedMotion();
  const { left, top } = projectOnFranceMap(city);
  const core = 34 + weight * 12;
  const halo = 58 + weight * 46;

  const settle = reducedMotion
    ? { duration: 0 }
    : ({ type: "spring", bounce: 0.2, duration: 0.35 } as const);

  return (
    <motion.button
      type="button"
      data-city={city.slug}
      onClick={(event) => onSelect(city, event.currentTarget)}
      aria-label={expansionContent.dot(city.name, votes)}
      aria-expanded={selected}
      {...(reducedMotion
        ? {}
        : { whileHover: { scale: 1.12 }, whileTap: { scale: 0.9 } })}
      transition={settle}
      className="group focus-ring absolute z-10 flex aspect-square w-[4.4%] -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full md:w-[2.2%]"
      style={{ left: `${left}%`, top: `${top}%` }}
    >
      {/* How wanted the city is, as light rather than as size. */}
      <span
        aria-hidden="true"
        className="pointer-events-none absolute rounded-full bg-[radial-gradient(circle,rgba(77,150,255,0.42)_0%,rgba(77,150,255,0)_70%)]"
        style={{ width: `${halo}%`, aspectRatio: "1" }}
      />

      {leading && !reducedMotion ? (
        <motion.span
          aria-hidden="true"
          className="pointer-events-none absolute rounded-full ring-1 ring-[#4D96FF]"
          style={{ width: `${core}%`, aspectRatio: "1" }}
          animate={{ scale: [1, 2.6], opacity: [0.5, 0] }}
          transition={{
            duration: 3.2,
            repeat: Infinity,
            ease: [0.16, 1, 0.3, 1],
          }}
        />
      ) : null}

      <motion.span
        aria-hidden="true"
        className={`relative rounded-full shadow-[0_2px_10px_rgba(0,0,0,0.55),0_0_14px_rgba(46,139,255,0.45)] transition-colors duration-200 ${
          backed
            ? "bg-[#2E8BFF] ring-2 ring-white"
            : "bg-[#2E8BFF] ring-1 ring-white/25 group-hover:bg-[#5AA6FF]"
        }`}
        style={{ width: `${core}%`, aspectRatio: "1" }}
        animate={{ scale: selected ? 1.35 : 1 }}
        transition={settle}
      />

      <span
        style={{ bottom: `calc(50% + ${core / 2}% + 7px)` }}
        className={`pointer-events-none absolute left-1/2 -translate-x-1/2 text-[11px] leading-none font-medium tracking-[0.005em] whitespace-nowrap text-white/85 transition-opacity duration-200 [text-shadow:0_1px_8px_rgba(0,0,0,0.9)] ${
          selected
            ? "opacity-0"
            : named
              ? "opacity-100"
              : "opacity-0 group-hover:opacity-100 group-focus-visible:opacity-100"
        }`}
      >
        {city.name}
      </span>
    </motion.button>
  );
}
