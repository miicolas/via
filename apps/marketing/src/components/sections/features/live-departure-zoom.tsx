"use client";

import type {
  DepartureFrame,
  DepartureFrameStatus,
  DeparturePreview,
} from "@/constants/departures";
import { CircleAlert, CircleArrowUp, Star } from "lucide-react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useEffect, useState, type ReactNode } from "react";
import { LiveSignalSymbol } from "./live-signal-symbol";

const STAR_POP = { type: "spring", bounce: 0.45, duration: 0.45 } as const;
const FRAME_SWAP = { duration: 0.42, ease: [0.22, 1, 0.36, 1] } as const;

// One place a status becomes a colour, so the pill, the glyph and the delay
// badge cannot disagree — the same accents as the app's departure board.
const STATUS_STYLE: Record<
  DepartureFrameStatus,
  { readonly pill: string; readonly accent: string; readonly badge: string }
> = {
  live: {
    pill: "bg-[#eaf8ed]",
    accent: "text-[#20bd57]",
    badge: "text-[#20bd57]",
  },
  early: {
    pill: "bg-[#eaf8ed]",
    accent: "text-[#20bd57]",
    badge: "text-[#20bd57]",
  },
  delayed: {
    pill: "bg-[#fdeceb]",
    accent: "text-[#ff3b30]",
    badge: "text-[#ff3b30]",
  },
};

function StatusGlyph({
  status,
}: {
  readonly status: DepartureFrameStatus;
}): ReactNode {
  if (status === "delayed")
    return <CircleAlert className="size-5 shrink-0" strokeWidth={2.4} />;
  if (status === "early")
    return <CircleArrowUp className="size-5 shrink-0" strokeWidth={2.4} />;
  return <LiveSignalSymbol />;
}

function deltaLabel(frame: DepartureFrame): string | null {
  if (frame.status === "delayed") return `+${frame.deltaMinutes} min`;
  if (frame.status === "early") return `−${frame.deltaMinutes} min`;
  return null;
}

function spokenStatus(frame: DepartureFrame, onTimeLabel: string): string {
  const plural = frame.deltaMinutes > 1 ? "minutes" : "minute";
  if (frame.status === "delayed")
    return `retard de ${frame.deltaMinutes} ${plural}`;
  if (frame.status === "early")
    return `en avance de ${frame.deltaMinutes} ${plural}`;
  return onTimeLabel;
}

export function LiveDepartureZoom({
  departure,
  className = "",
}: {
  readonly departure: DeparturePreview;
  readonly className?: string;
}): ReactNode {
  const reduceMotion = useReducedMotion();
  const [frameIndex, setFrameIndex] = useState(0);
  const [favorites, setFavorites] = useState<readonly boolean[]>(
    departure.rows.map((row) => row.initialFavorite),
  );

  useEffect(() => {
    if (reduceMotion) return;

    const interval = window.setInterval(() => {
      setFrameIndex((index) => index + 1);
    }, 2400);

    return () => window.clearInterval(interval);
  }, [reduceMotion]);

  const toggleFavorite = (rowIndex: number): void => {
    setFavorites((current) =>
      current.map((value, index) => (index === rowIndex ? !value : value)),
    );
  };

  return (
    <div
      className={`rounded-[1.75rem] border border-black/8 bg-white/94 p-2 shadow-[0_24px_70px_rgba(0,0,0,0.14)] backdrop-blur-xl sm:p-2.5 ${className}`}
    >
      {departure.rows.map((row, rowIndex) => {
        const frame: DepartureFrame =
          row.frames[frameIndex % row.frames.length] ?? row.frames[0];
        const favorite = favorites[rowIndex] ?? false;
        const style = STATUS_STYLE[frame.status];
        const delta = deltaLabel(frame);

        return (
          <div
            key={row.id}
            className="flex items-center gap-3 rounded-[1.25rem] p-2.5 sm:gap-4 sm:p-3"
          >
            <span
              className="grid size-11 shrink-0 place-items-center rounded-[0.8rem] border border-white/65 text-xl font-bold shadow-sm sm:size-12"
              style={{
                backgroundColor: row.line.color,
                color: row.line.textColor,
              }}
              aria-hidden="true"
            >
              {row.line.shortName}
            </span>

            <span className="flex min-w-0 flex-1 flex-col gap-0.5">
              <span className="truncate text-sm font-semibold tracking-tight text-neutral-950 sm:text-base">
                {row.destination}
              </span>
              <span
                className="flex items-center gap-1.5 text-[0.7rem] leading-none font-medium"
                aria-hidden="true"
              >
                <span
                  className={`text-neutral-400 tabular-nums ${delta ? "line-through" : ""}`}
                >
                  {frame.scheduled}
                </span>
                <AnimatePresence mode="popLayout" initial={false}>
                  <motion.span
                    key={delta ?? departure.onTimeLabel}
                    className={
                      delta ? `font-bold ${style.badge}` : "text-neutral-500"
                    }
                    initial={reduceMotion ? false : { y: -8, opacity: 0 }}
                    animate={{ y: 0, opacity: 1 }}
                    exit={reduceMotion ? { opacity: 0 } : { y: 8, opacity: 0 }}
                    transition={reduceMotion ? { duration: 0 } : FRAME_SWAP}
                  >
                    {delta ?? departure.onTimeLabel}
                  </motion.span>
                </AnimatePresence>
              </span>
            </span>

            <motion.button
              type="button"
              onClick={() => toggleFavorite(rowIndex)}
              whileTap={reduceMotion ? {} : { scale: 0.8 }}
              transition={STAR_POP}
              className="grid size-9 shrink-0 cursor-pointer place-items-center rounded-full"
              aria-pressed={favorite}
              aria-label={`Favori ${row.destination}`}
            >
              <AnimatePresence mode="popLayout" initial={false}>
                <motion.span
                  key={String(favorite)}
                  className="grid place-items-center"
                  initial={reduceMotion ? false : { scale: 0.4, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  exit={
                    reduceMotion ? { opacity: 0 } : { scale: 0.4, opacity: 0 }
                  }
                  transition={reduceMotion ? { duration: 0 } : STAR_POP}
                  aria-hidden="true"
                >
                  <Star
                    className={`size-5 ${favorite ? "fill-[#f5b301] text-[#f5b301]" : "text-neutral-300"}`}
                    strokeWidth={2}
                  />
                </motion.span>
              </AnimatePresence>
            </motion.button>

            <div
              className={`flex shrink-0 items-center gap-1.5 rounded-full px-3 py-2 transition-colors duration-300 sm:px-3.5 ${style.pill} ${style.accent}`}
            >
              <span className="sr-only">
                {`${row.destination}, dans ${frame.minutes} ${frame.minutes > 1 ? "minutes" : "minute"}, ${spokenStatus(frame, departure.onTimeLabel)}`}
              </span>
              <AnimatePresence mode="popLayout" initial={false}>
                <motion.span
                  key={frame.status}
                  className="grid place-items-center"
                  initial={reduceMotion ? false : { scale: 0.5, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  exit={
                    reduceMotion ? { opacity: 0 } : { scale: 0.5, opacity: 0 }
                  }
                  transition={reduceMotion ? { duration: 0 } : STAR_POP}
                  aria-hidden="true"
                >
                  <StatusGlyph status={frame.status} />
                </motion.span>
              </AnimatePresence>
              <span
                className="relative grid h-7 min-w-6 place-items-center overflow-hidden text-2xl leading-none font-bold text-neutral-950 tabular-nums"
                aria-hidden="true"
              >
                <AnimatePresence initial={false} mode="popLayout">
                  <motion.span
                    key={`${frame.status}-${frame.minutes}`}
                    className="absolute"
                    initial={reduceMotion ? false : { y: -22, opacity: 0 }}
                    animate={{ y: 0, opacity: 1 }}
                    exit={reduceMotion ? {} : { y: 22, opacity: 0 }}
                    transition={FRAME_SWAP}
                  >
                    {frame.minutes}
                  </motion.span>
                </AnimatePresence>
              </span>
              <span
                className="text-[0.67rem] font-semibold tracking-wide text-neutral-500"
                aria-hidden="true"
              >
                {departure.unit}
              </span>
            </div>
          </div>
        );
      })}
    </div>
  );
}
