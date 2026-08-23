"use client";

import type { VotableCity } from "@/constants/cities";
import { expansionContent } from "@/constants/expansion";
import { submitCityVote, type CityDemandBoard } from "@/lib/city-demand";
import { FRANCE_FOCUS } from "@/lib/france-map";
import { useMediaQuery } from "@/lib/use-media-query";
import { useStoredList } from "@/lib/stored-list";
import Image from "next/image";
import { AnimatePresence } from "motion/react";
import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from "react";
import { CityDemandDot } from "./city-demand-dot";
import { CityVoteCard, type VoteCardAnchor } from "./city-vote-card";
import { DemandLeaderboard, type LeaderboardEntry } from "./demand-leaderboard";

interface CoverageMapProps {
  readonly cities: readonly VotableCity[];
  /** Counted on the server; `null` when the poll could not be reached. */
  readonly board: CityDemandBoard | null;
}

const BACKED_STORAGE_KEY = "metyro.city-demand.backed";
const LEADERBOARD_LENGTH = 6;
/** How many cities keep their name on the map when nothing is selected. */
const NAMED_ON_MAP = 3;

/**
 * The drawing fades out as it leaves France, so the country reads as the lit
 * subject and its neighbours as the room around it rather than as shapes of
 * their own. Anchored on France, not on the frame, so the same mask holds when
 * small screens slide the plane sideways.
 */
const MAP_VIGNETTE =
  "radial-gradient(46% 60% at 28% 56%, #000 30%, rgba(0,0,0,0.34) 58%, transparent 84%)";

export function CoverageMap({ cities, board }: CoverageMapProps): ReactNode {
  const frameRef = useRef<HTMLDivElement>(null);
  const [counted, setCounted] = useState(board);
  const [selected, setSelected] = useState<VotableCity | null>(null);
  const [anchor, setAnchor] = useState<VoteCardAnchor | null>(null);
  const [pending, setPending] = useState(false);
  const [failed, setFailed] = useState(false);

  const popoverPlacement = useMediaQuery("(min-width: 768px)");

  /**
   * The cities this browser has already backed. The API refuses a second vote
   * for the same one anyway; remembering them is what lets the card say so
   * before the visitor spends a tap finding out. The session's own votes are
   * held separately so a browser that refuses storage still sees its vote land.
   */
  const [remembered, remember] = useStoredList(BACKED_STORAGE_KEY);
  const [castHere, setCastHere] = useState<readonly string[]>([]);
  const backed = useMemo(
    () => new Set([...remembered, ...castHere]),
    [castHere, remembered],
  );

  const demand = useMemo(() => {
    const byCity = new Map(counted?.cities.map((city) => [city.slug, city]));
    const leaderVotes = Math.max(
      1,
      ...(counted?.cities.map((city) => city.votes) ?? [0]),
    );

    return {
      votesFor: (slug: string) => byCity.get(slug)?.votes ?? 0,
      rankFor: (slug: string) => byCity.get(slug)?.rank ?? null,
      weightFor: (slug: string) => (byCity.get(slug)?.votes ?? 0) / leaderVotes,
    };
  }, [counted]);

  const entries = useMemo<readonly LeaderboardEntry[]>(() => {
    const byCity = new Map(cities.map((city) => [city.slug, city]));
    return (counted?.cities ?? [])
      .filter((city) => city.rank !== null)
      .slice(0, LEADERBOARD_LENGTH)
      .flatMap((entry) => {
        const city = byCity.get(entry.slug);
        const rank = entry.rank;
        return city && rank !== null
          ? [{ city, votes: entry.votes, rank }]
          : [];
      });
  }, [cities, counted]);

  const measure = useCallback(
    (dot: HTMLElement | null): VoteCardAnchor | null => {
      const frame = frameRef.current;
      if (!dot || !frame || !popoverPlacement) return null;

      const frameBox = frame.getBoundingClientRect();
      const dotBox = dot.getBoundingClientRect();
      return {
        x: dotBox.left + dotBox.width / 2 - frameBox.left,
        y: dotBox.top + dotBox.height / 2 - frameBox.top,
        frameWidth: frameBox.width,
        frameHeight: frameBox.height,
      };
    },
    [popoverPlacement],
  );

  const select = useCallback(
    (city: VotableCity, dot: HTMLElement | null) => {
      setFailed(false);
      setSelected(city);
      setAnchor(measure(dot));
    },
    [measure],
  );

  const selectBySlug = useCallback(
    (city: VotableCity) => {
      const dot = frameRef.current?.querySelector<HTMLElement>(
        `[data-city="${city.slug}"]`,
      );
      select(city, dot ?? null);
    },
    [select],
  );

  /** A resized window moves every dot; the card has to follow or leave. */
  useEffect(() => {
    if (!selected) return;

    const reposition = () => {
      const dot = frameRef.current?.querySelector<HTMLElement>(
        `[data-city="${selected.slug}"]`,
      );
      setAnchor(measure(dot ?? null));
    };

    window.addEventListener("resize", reposition);
    return () => window.removeEventListener("resize", reposition);
  }, [measure, selected]);

  useEffect(() => {
    if (!selected) return;

    const onPointerDown = (event: PointerEvent) => {
      const target = event.target as HTMLElement | null;
      if (target?.closest("[data-city], [role='dialog']")) return;
      setSelected(null);
    };

    window.addEventListener("pointerdown", onPointerDown);
    return () => window.removeEventListener("pointerdown", onPointerDown);
  }, [selected]);

  const vote = useCallback(async () => {
    if (!selected || backed.has(selected.slug)) return;

    setPending(true);
    setFailed(false);
    try {
      const result = await submitCityVote(selected.slug);
      setCounted({ cities: result.cities, totalVotes: result.totalVotes });
      setCastHere((current) => [...current, selected.slug]);
      remember(selected.slug);
    } catch {
      setFailed(true);
    } finally {
      setPending(false);
    }
  }, [backed, remember, selected]);

  return (
    <>
      <div
        ref={frameRef}
        className="relative aspect-square w-full overflow-hidden md:aspect-[100/50]"
        style={
          {
            "--map-width": "330%",
            "--focus-x": `${FRANCE_FOCUS.left}%`,
            "--focus-y": `${FRANCE_FOCUS.top}%`,
          } as CSSProperties
        }
      >
        {/*
         * The drawing is Europe-wide, and France is a quarter of it. Rather than
         * two illustrations, the plane below is scaled up and slid until France
         * is centred on small screens, and left at its full width on large ones
         * — one set of coordinates, two framings.
         */}
        <div
          className="absolute top-1/2 left-1/2 md:[--focus-x:32%] md:[--focus-y:53%] md:[--map-width:158%]"
          style={{
            width: "var(--map-width)",
            transform:
              "translate(calc(-1 * var(--focus-x)), calc(-1 * var(--focus-y)))",
          }}
        >
          <Image
            src="/illustrations/france-coverage.svg?v=6"
            alt=""
            width={1362}
            height={904}
            sizes="(max-width: 767px) 330vw, 158vw"
            className="block h-auto w-full max-w-none"
            style={{
              maskImage: MAP_VIGNETTE,
              WebkitMaskImage: MAP_VIGNETTE,
            }}
            unoptimized
          />

          {/*
           * Where Metyro already runs. The tile used to be drawn into the
           * illustration; it is written here instead so it keeps its size when
           * the map is scaled up, and so its caption can hang off the tile
           * itself rather than off a percentage of the drawing.
           */}
          <div
            className="pointer-events-none absolute top-[50.8%] left-[28.2%] flex aspect-square w-[4.1%] -translate-x-1/2 -translate-y-1/2 items-center justify-center md:w-[2.4%]"
            aria-hidden="true"
          >
            <span className="absolute -inset-[55%] rounded-full bg-[radial-gradient(circle,rgba(77,150,255,0.4)_0%,rgba(77,150,255,0)_70%)]" />
            <span className="absolute inset-0 rounded-[28%] bg-gradient-to-br from-[#7CB6FF] via-[#2E8BFF] to-[#0B57D0] shadow-[0_10px_26px_-8px_rgba(11,87,208,0.95),inset_0_1px_0_rgba(255,255,255,0.55)] ring-1 ring-white/45" />

            <p className="absolute top-[calc(100%+10px)] left-1/2 -translate-x-1/2 text-center leading-none">
              <span className="block text-[15px] font-semibold tracking-[-0.01em] whitespace-nowrap text-white sm:text-lg">
                {expansionContent.served.region}
              </span>
              <span className="mt-1.5 inline-flex items-center gap-1.5 text-[11px] font-medium whitespace-nowrap text-[#7CB6FF]">
                <span className="size-1.5 rounded-full bg-[#2E8BFF] shadow-[0_0_8px_rgba(46,139,255,0.9)]" />
                {expansionContent.served.status}
              </span>
            </p>
          </div>

          {cities.map((city) => {
            const rank = demand.rankFor(city.slug);
            return (
              <CityDemandDot
                key={city.slug}
                city={city}
                votes={demand.votesFor(city.slug)}
                weight={demand.weightFor(city.slug)}
                leading={rank === 1}
                named={rank !== null && rank <= NAMED_ON_MAP}
                selected={selected?.slug === city.slug}
                backed={backed.has(city.slug)}
                onSelect={select}
              />
            );
          })}
        </div>

        {/*
         * One card for the whole run of selections, keyed on nothing that
         * changes between cities: picking another dot slides this one over
         * rather than dismissing a card and presenting a second.
         */}
        {/* Where the frame ends, the drawing is faded out rather than cut. */}
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-x-0 bottom-0 h-24 bg-gradient-to-b from-transparent to-[#242424]"
        />

        <AnimatePresence>
          {selected ? (
            <CityVoteCard
              key="vote-card"
              city={selected}
              votes={demand.votesFor(selected.slug)}
              rank={demand.rankFor(selected.slug)}
              backed={backed.has(selected.slug)}
              pending={pending}
              failed={failed}
              anchor={anchor}
              onVote={vote}
              onClose={() => setSelected(null)}
            />
          ) : null}
        </AnimatePresence>
      </div>

      <div className="px-6 pt-14 sm:pt-16">
        <DemandLeaderboard
          entries={entries}
          totalVotes={counted?.totalVotes ?? 0}
          unavailable={counted === null}
          onSelect={selectBySlug}
        />
      </div>
    </>
  );
}
