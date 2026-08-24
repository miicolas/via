"use client";

import type { VotableCity } from "@/constants/cities";
import { expansionContent } from "@/constants/expansion";
import { useReducedMotion } from "@/lib/motion";
import { Check, X } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import {
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";

export interface VoteCardAnchor {
  /** Centre of the dot, in pixels inside the map frame. */
  readonly x: number;
  readonly y: number;
  readonly frameWidth: number;
  readonly frameHeight: number;
}

interface CityVoteCardProps {
  readonly city: VotableCity;
  readonly votes: number;
  readonly rank: number | null;
  readonly backed: boolean;
  readonly pending: boolean;
  readonly failed: boolean;
  /** `null` on small screens, where the card is a sheet rather than a popover. */
  readonly anchor: VoteCardAnchor | null;
  readonly onVote: () => void;
  readonly onClose: () => void;
}

const CARD_WIDTH = 264;
const GAP = 22;
const EDGE = 16;

/**
 * The vote itself. A popover beside the dot where there is room for one, a
 * sheet at the bottom of the screen where there is not — the same card either
 * way, so the wording and the counter never diverge between the two.
 *
 * It is mounted once for the whole session of selections rather than per city:
 * choosing another dot slides this card over to it instead of dismissing one
 * card and presenting another, which is what keeps the gesture continuous.
 */
export function CityVoteCard({
  city,
  votes,
  rank,
  backed,
  pending,
  failed,
  anchor,
  onVote,
  onClose,
}: CityVoteCardProps): ReactNode {
  const reducedMotion = useReducedMotion();
  const cardRef = useRef<HTMLDivElement>(null);
  /* Seeded with the height of a card that has a rank, so the very first
   opening lands within a few pixels of its final place rather than
   springing in from a zero-height guess. */
  const [height, setHeight] = useState(196);

  /** The card answers the dot: the reader should land in it, not keep scanning. */
  useEffect(() => {
    cardRef.current?.focus({ preventScroll: true });
  }, [city.slug]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [onClose]);

  /*
   * Its own height decides where it sits, so it is measured rather than
   * guessed: a card with a rank is taller than one without, and a guess puts
   * the caret off the dot by exactly that difference.
   */
  useLayoutEffect(() => {
    const card = cardRef.current;
    if (!card) return;

    setHeight(card.offsetHeight);
    const observer = new ResizeObserver(([entry]) => {
      if (entry) setHeight(entry.contentRect.height);
    });
    observer.observe(card);
    return () => observer.disconnect();
  }, []);

  const place = anchor ? placeCard(anchor, height) : null;

  /* Apple's move-and-settle: no overshoot when repositioning, a little when it
   * arrives under a finger. */
  const glide = reducedMotion
    ? { duration: 0 }
    : ({ type: "spring", bounce: 0, duration: 0.4 } as const);
  const arrive = reducedMotion
    ? { duration: 0 }
    : ({ type: "spring", bounce: 0.14, duration: 0.36 } as const);

  const enter = place
    ? { opacity: 0, scale: 0.86 }
    : { opacity: 0, y: 24, scale: 0.98 };
  const leave = place
    ? { opacity: 0, scale: 0.9 }
    : { opacity: 0, y: 24, scale: 0.98 };

  return (
    <motion.div
      ref={cardRef}
      role="dialog"
      aria-label={city.name}
      tabIndex={-1}
      initial={
        reducedMotion ? { opacity: 0 } : { ...enter, ...position(place) }
      }
      animate={{ opacity: 1, scale: 1, y: 0, ...position(place) }}
      exit={reducedMotion ? { opacity: 0 } : leave}
      transition={
        reducedMotion
          ? { duration: 0 }
          : { default: arrive, x: glide, y: glide }
      }
      style={{
        transformOrigin: place
          ? `${place.side === "right" ? 0 : CARD_WIDTH}px ${place.originY}px`
          : "center bottom",
        ...(place ? { left: 0, top: 0, width: CARD_WIDTH } : {}),
      }}
      /*
       * No Tailwind `translate-*` on this element: motion writes `transform`
       * inline, and the class would lose to it. The popover is placed through
       * `x`/`y` for that reason, and the sheet through `inset-x`.
       */
      className={`z-[60] rounded-[26px] bg-[#16171A]/78 p-5 shadow-[inset_0_1px_0_rgba(255,255,255,0.14),0_30px_80px_-30px_rgba(0,0,0,0.95)] ring-1 ring-white/12 backdrop-blur-2xl backdrop-saturate-150 ${
        place
          ? "absolute"
          : "fixed inset-x-4 bottom-[max(1rem,env(safe-area-inset-bottom))] sm:mx-auto sm:max-w-72"
      }`}
    >
      <button
        type="button"
        onClick={onClose}
        aria-label={expansionContent.card.close}
        className="focus-ring group absolute top-2 right-2 flex size-11 items-center justify-center rounded-full"
      >
        <span
          className="flex size-7 items-center justify-center rounded-full bg-white/10 text-white/60 transition-colors group-hover:bg-white/18 group-hover:text-white"
          aria-hidden="true"
        >
          <X className="size-3.5" />
        </span>
      </button>

      <div key={city.slug} className="relative">
        <motion.div
          initial={reducedMotion ? false : { opacity: 0, filter: "blur(4px)" }}
          animate={{ opacity: 1, filter: "blur(0px)" }}
          transition={{ duration: reducedMotion ? 0 : 0.18 }}
        >
          <p className="pr-8 text-[17px] leading-tight font-semibold tracking-[-0.01em] text-white">
            {city.name}
          </p>
          <p className="mt-0.5 text-[12px] text-white/45">{city.region}</p>

          {votes === 0 ? (
            <p className="mt-4 text-[13px] text-white/60">
              {expansionContent.card.none}
            </p>
          ) : (
            <>
              <div className="mt-4 flex items-baseline gap-2.5">
                <AnimatePresence mode="popLayout" initial={false}>
                  <motion.span
                    key={votes}
                    initial={
                      reducedMotion ? false : { y: "-0.55em", opacity: 0 }
                    }
                    animate={{ y: 0, opacity: 1 }}
                    exit={
                      reducedMotion
                        ? { opacity: 0 }
                        : { y: "0.55em", opacity: 0 }
                    }
                    transition={
                      reducedMotion
                        ? { duration: 0 }
                        : { type: "spring", bounce: 0.24, duration: 0.5 }
                    }
                    className="text-[34px] leading-none font-semibold tracking-[-0.03em] text-white tabular-nums"
                  >
                    {expansionContent.card.count(votes)}
                  </motion.span>
                </AnimatePresence>

                {rank !== null ? (
                  <span className="rounded-full bg-white/8 px-2 py-1 text-[11px] leading-none font-medium text-[#8FC0FF]">
                    {expansionContent.card.rank(rank)}
                  </span>
                ) : null}
              </div>
              <p className="mt-1.5 text-[13px] text-white/55">
                {expansionContent.card.demand(votes)}
              </p>
            </>
          )}
        </motion.div>
      </div>

      <motion.button
        type="button"
        onClick={onVote}
        disabled={backed || pending}
        {...(backed || pending || reducedMotion
          ? {}
          : { whileHover: { scale: 1.015 }, whileTap: { scale: 0.97 } })}
        transition={arrive}
        className={`focus-ring mt-5 flex h-11 w-full items-center justify-center gap-2 rounded-2xl text-[15px] font-semibold tracking-[-0.01em] transition-colors duration-300 ${
          backed
            ? "bg-white/12 text-white/75"
            : "bg-white text-[#141414] hover:bg-white/92 disabled:opacity-60"
        }`}
      >
        <AnimatePresence mode="popLayout" initial={false}>
          {backed ? (
            <motion.span
              key="voted"
              initial={reducedMotion ? false : { opacity: 0, scale: 0.7 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.7 }}
              transition={
                reducedMotion
                  ? { duration: 0 }
                  : { type: "spring", bounce: 0.35, duration: 0.45 }
              }
              className="flex items-center gap-2"
            >
              <Check className="size-4" aria-hidden="true" />
              {expansionContent.card.voted}
            </motion.span>
          ) : (
            <motion.span
              key="vote"
              initial={reducedMotion ? false : { opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.9 }}
              transition={{ duration: reducedMotion ? 0 : 0.16 }}
            >
              {expansionContent.card.action}
            </motion.span>
          )}
        </AnimatePresence>
      </motion.button>

      <p aria-live="polite" className="sr-only">
        {backed ? expansionContent.card.voted : ""}
      </p>
      {failed ? (
        <p role="alert" className="mt-3 text-[12px] text-[#ff9a9a]">
          {expansionContent.card.failed}
        </p>
      ) : null}
    </motion.div>
  );
}

function position(place: CardPlacement | null) {
  return place ? { x: place.left, y: place.top } : {};
}

interface CardPlacement {
  readonly left: number;
  readonly top: number;
  readonly side: "left" | "right";
  /** Where the dot falls down the card's own edge: the point it grows out of. */
  readonly originY: number;
}

/**
 * Beside the dot, on whichever side has room, and never past the top or bottom
 * of the frame — a card that hangs off the map takes the dot's answer with it.
 */
function placeCard(anchor: VoteCardAnchor, height: number): CardPlacement {
  const side =
    anchor.frameWidth - anchor.x > CARD_WIDTH + GAP * 2 ? "right" : "left";
  const left = clamp(
    side === "right" ? anchor.x + GAP : anchor.x - CARD_WIDTH - GAP,
    EDGE,
    Math.max(EDGE, anchor.frameWidth - CARD_WIDTH - EDGE),
  );
  const top = clamp(
    anchor.y - height / 2,
    EDGE,
    Math.max(EDGE, anchor.frameHeight - height - EDGE),
  );

  return { left, top, side, originY: clamp(anchor.y - top, 0, height) };
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}
