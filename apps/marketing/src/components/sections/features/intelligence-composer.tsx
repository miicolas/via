"use client";

import type { FeaturesContent } from "@/constants/features";
import { AppleIntelligenceGlyph } from "@/components/ui/apple-intelligence-glyph";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useEffect, useState, type ReactNode } from "react";

const TYPE_INTERVAL = 90;
const HOLD_DURATION = 3600;

type Prompts = FeaturesContent["intelligence"]["prompts"];

export function IntelligenceComposer({
  prompts,
}: {
  readonly prompts: Prompts;
}): ReactNode {
  const reduceMotion = useReducedMotion();
  const [promptIndex, setPromptIndex] = useState(0);
  const [resultIndex, setResultIndex] = useState(0);
  const [userTouched, setUserTouched] = useState(false);
  const prompt = prompts[promptIndex] ?? prompts[0];
  const text = prompt?.text ?? "";
  const [length, setLength] = useState(text.length);

  useEffect(() => {
    if (reduceMotion) return;

    let index = 0;
    let timer = 0;

    const typeNext = (): void => {
      setLength(index);
      if (index < text.length) {
        index += 1;
        timer = window.setTimeout(typeNext, TYPE_INTERVAL);
        return;
      }
      setResultIndex(promptIndex);
      if (!userTouched) {
        timer = window.setTimeout(() => {
          setLength(0);
          setPromptIndex((current) => (current + 1) % prompts.length);
        }, HOLD_DURATION);
      }
    };

    timer = window.setTimeout(typeNext, TYPE_INTERVAL * 2);
    return () => window.clearTimeout(timer);
  }, [text, promptIndex, reduceMotion, userTouched, prompts.length]);

  const choosePrompt = (index: number): void => {
    setUserTouched(true);
    setPromptIndex(index);
    setLength(reduceMotion ? (prompts[index]?.text ?? "").length : 0);
  };

  const shown = reduceMotion
    ? prompts[promptIndex]
    : (prompts[resultIndex] ?? prompts[0]);
  const shownKey = reduceMotion ? promptIndex : resultIndex;

  return (
    <div className="flex w-full flex-col gap-3">
      <div
        className="rounded-full bg-gradient-to-r from-indigo-500 via-purple-500 to-orange-400 p-[1.5px] shadow-[0_16px_40px_rgba(124,58,237,0.22)]"
        aria-label={text}
      >
        <span className="flex items-center gap-2.5 rounded-full bg-white/96 py-3 pr-5 pl-3.5">
          <motion.span
            className="shrink-0 text-purple-600"
            animate={reduceMotion ? false : { rotate: 360 }}
            transition={{ duration: 14, ease: "linear", repeat: Infinity }}
            aria-hidden="true"
          >
            <AppleIntelligenceGlyph className="size-5" strokeWidth={1.8} />
          </motion.span>
          <span
            className="min-w-0 truncate text-sm font-medium whitespace-pre text-neutral-950"
            aria-hidden="true"
          >
            {reduceMotion ? text : text.slice(0, length)}
            <motion.span
              className="ml-px inline-block h-4 w-px translate-y-0.5 bg-neutral-950 align-baseline"
              animate={reduceMotion ? false : { opacity: [1, 0, 1] }}
              transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
            />
          </span>
        </span>
      </div>
      <div
        className="flex flex-wrap gap-1.5"
        role="group"
        aria-label="Exemples de trajets"
      >
        {prompts.map((example, index) => (
          <motion.button
            key={example.label}
            type="button"
            onClick={() => choosePrompt(index)}
            whileTap={reduceMotion ? {} : { scale: 0.94 }}
            transition={{ type: "spring", bounce: 0, duration: 0.3 }}
            className={`cursor-pointer rounded-full px-3 py-1.5 text-xs font-semibold transition-colors duration-300 ${
              index === promptIndex
                ? "bg-purple-600/12 text-purple-700"
                : "bg-white/70 text-neutral-600 hover:bg-white"
            }`}
            aria-pressed={index === promptIndex}
            aria-label={`Essayer : ${example.text}`}
          >
            {example.label}
          </motion.button>
        ))}
      </div>
      <div className="min-h-[72px]">
        <AnimatePresence mode="popLayout" initial={false}>
          {shown && (
            <motion.div
              key={shownKey}
              initial={
                reduceMotion ? false : { opacity: 0, y: 12, scale: 0.95 }
              }
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={reduceMotion ? { opacity: 0 } : { opacity: 0, scale: 0.95 }}
              transition={
                reduceMotion
                  ? { duration: 0 }
                  : { type: "spring", bounce: 0.2, duration: 0.5 }
              }
              className="flex items-center gap-3 rounded-2xl border border-black/8 bg-white/96 p-3.5 shadow-[0_18px_50px_rgba(0,0,0,0.12)]"
              aria-label={`Itinéraire proposé : ligne ${shown.result.line.shortName}, ${shown.result.destination}, ${shown.result.note}`}
            >
              <span
                className="grid size-10 shrink-0 place-items-center rounded-[0.7rem] text-lg font-bold"
                style={{
                  backgroundColor: shown.result.line.color,
                  color: shown.result.line.textColor,
                }}
                aria-hidden="true"
              >
                {shown.result.line.shortName}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-sm font-semibold tracking-tight text-neutral-950">
                  {shown.result.destination}
                </span>
                <span className="block truncate text-xs text-neutral-500">
                  {shown.result.note}
                </span>
              </span>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
