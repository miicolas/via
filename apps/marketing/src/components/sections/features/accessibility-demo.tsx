"use client";

import { ElevatorGlyph } from "@/components/ui/elevator-glyph";
import type { FeaturesContent } from "@/constants/features";
import { Accessibility } from "lucide-react";
import {
  animate,
  AnimatePresence,
  motion,
  useMotionValue,
  useReducedMotion,
  useTransform,
} from "motion/react";
import { useRef, useState, type ReactNode } from "react";

/** Course du pouce : largeur de piste − diamètre du pouce − marges. */
const KNOB_TRAVEL = 20;
const TOGGLE_SPRING = { type: "spring", bounce: 0.22, duration: 0.45 } as const;
const PRESS_SPRING = { type: "spring", bounce: 0, duration: 0.22 } as const;
const REVEAL_SPRING = { type: "spring", bounce: 0.18, duration: 0.5 } as const;

/** Décélération façon UIScrollView : où le geste s’arrêterait tout seul. */
function project(velocity: number, decelerationRate = 0.99): number {
  return ((velocity / 1000) * decelerationRate) / (1 - decelerationRate);
}

export function AccessibilityDemo({
  content,
}: {
  readonly content: FeaturesContent["highlights"]["accessibility"];
}): ReactNode {
  const reduceMotion = useReducedMotion();
  const [enabled, setEnabled] = useState(true);
  const [pressed, setPressed] = useState(false);
  const dragging = useRef(false);
  const dragged = useRef(false);

  const x = useMotionValue(KNOB_TRAVEL);
  const progress = useTransform(x, [0, KNOB_TRAVEL], [0, 1], { clamp: true });
  const fillScaleX = useTransform(progress, [0, 1], [0.42, 1]);
  const fillScaleY = useTransform(progress, [0, 1], [0.6, 1]);
  const fillOpacity = useTransform(progress, [0, 0.35, 1], [0, 0.75, 1]);

  const settle = (next: boolean, velocity = 0): void => {
    setEnabled(next);
    animate(
      x,
      next ? KNOB_TRAVEL : 0,
      reduceMotion ? { duration: 0 } : { ...TOGGLE_SPRING, velocity },
    );
  };

  return (
    <div className="rounded-[1.75rem] border border-black/8 bg-white/94 p-4 shadow-[0_24px_70px_rgba(0,0,0,0.14)]">
      <div className="flex items-center justify-between gap-3 p-1">
        <span className="flex min-w-0 items-center gap-3">
          <span
            className="grid size-10 shrink-0 place-items-center rounded-full bg-[#0a84ff]/12 text-[#0a84ff]"
            aria-hidden="true"
          >
            <Accessibility className="size-5" strokeWidth={2} />
          </span>
          <span className="truncate text-base font-semibold tracking-tight text-neutral-950">
            {content.toggleLabel}
          </span>
        </span>
        <button
          type="button"
          onPointerDown={() => {
            dragged.current = false;
            setPressed(true);
          }}
          onPointerUp={() => setPressed(false)}
          onPointerCancel={() => setPressed(false)}
          onPointerLeave={() => {
            if (!dragging.current) setPressed(false);
          }}
          onBlur={() => setPressed(false)}
          onClick={() => {
            if (dragged.current) return;
            settle(!enabled);
          }}
          className="relative h-8 w-[52px] shrink-0 cursor-pointer touch-none rounded-full bg-[#e5e5ea]"
          role="switch"
          aria-checked={enabled}
          aria-label={content.toggleLabel}
        >
          <motion.span
            className="absolute inset-0 rounded-full bg-[#34c759]"
            style={{
              scaleX: fillScaleX,
              scaleY: fillScaleY,
              opacity: fillOpacity,
              originX: 0.31,
              originY: 0.5,
            }}
            aria-hidden="true"
          />
          <motion.span
            className="absolute top-1 left-1 size-6 rounded-full bg-white shadow-md"
            style={{ x, originX: enabled ? 1 : 0, originY: 0.5 }}
            animate={{ scaleX: pressed ? 1.26 : 1 }}
            transition={reduceMotion ? { duration: 0 } : PRESS_SPRING}
            drag="x"
            dragConstraints={{ left: 0, right: KNOB_TRAVEL }}
            dragElastic={0.08}
            dragMomentum={false}
            onDragStart={() => {
              dragging.current = true;
              dragged.current = true;
            }}
            onDragEnd={(_, info) => {
              dragging.current = false;
              setPressed(false);
              const projected = x.get() + project(info.velocity.x);
              settle(projected > KNOB_TRAVEL / 2, info.velocity.x);
            }}
            aria-hidden="true"
          />
        </button>
      </div>
      <AnimatePresence initial={false}>
        {enabled && (
          <motion.div
            key="status"
            initial={
              reduceMotion
                ? { opacity: 0 }
                : { height: 0, opacity: 0, filter: "blur(10px)" }
            }
            animate={{ height: "auto", opacity: 1, filter: "blur(0px)" }}
            exit={
              reduceMotion
                ? { opacity: 0 }
                : { height: 0, opacity: 0, filter: "blur(10px)" }
            }
            transition={
              reduceMotion
                ? { duration: 0 }
                : { ...REVEAL_SPRING, opacity: { duration: 0.2 } }
            }
            className="overflow-hidden"
          >
            <motion.div
              initial={reduceMotion ? false : { scale: 0.94, y: -6 }}
              animate={{ scale: 1, y: 0 }}
              exit={reduceMotion ? {} : { scale: 0.96, y: -4 }}
              transition={reduceMotion ? { duration: 0 } : REVEAL_SPRING}
              style={{ transformOrigin: "top center" }}
              className="mt-3 flex items-center gap-3 rounded-2xl bg-[#eaf8ed] p-3.5"
            >
              <span
                className="grid size-9 shrink-0 place-items-center rounded-full bg-[#20bd57]/14 text-[#17a34a]"
                aria-hidden="true"
              >
                <ElevatorGlyph className="size-5" strokeWidth={1.9} />
              </span>
              <span className="min-w-0">
                <span className="block truncate text-sm font-semibold text-neutral-950">
                  {content.status}
                </span>
                <span className="block truncate text-xs text-neutral-500">
                  {content.detail}
                </span>
              </span>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
