"use client";

import { useReducedMotion } from "@/lib/motion";
import { useEffect, useRef, useState, type ReactNode } from "react";

export function BlurHeadlineSection({
  text,
}: {
  readonly text: string;
}): ReactNode {
  const containerRef = useRef<HTMLElement>(null);
  const reduceMotion = useReducedMotion();
  const [scrollProgress, setScrollProgress] = useState(0);
  const words = text.split(" ");

  useEffect(() => {
    if (reduceMotion) return;
    const container = containerRef.current;
    if (!container) return;
    let ticking = false;

    const handleScroll = (): void => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(() => {
        const rect = container.getBoundingClientRect();
        const startOffset = window.innerHeight * 0.9;
        const endOffset = window.innerHeight * 0.25;
        setScrollProgress(
          Math.min(
            1,
            Math.max(0, (startOffset - rect.top) / (startOffset - endOffset)),
          ),
        );
        ticking = false;
      });
    };

    window.addEventListener("scroll", handleScroll, { passive: true });
    handleScroll();
    return () => window.removeEventListener("scroll", handleScroll);
  }, [reduceMotion]);

  return (
    <section ref={containerRef} className="w-full bg-background px-6 py-24">
      <div className="mx-auto max-w-5xl">
        <p className="text-left text-3xl leading-snug font-medium tracking-tight text-foreground sm:text-4xl lg:text-5xl lg:leading-snug">
          {words.map((word, index) => {
            const wordStart = index / words.length;
            const wordEnd = wordStart + 1 / words.length;
            const progress = reduceMotion
              ? 1
              : Math.min(
                  1,
                  Math.max(
                    0,
                    (scrollProgress - wordStart) / (wordEnd - wordStart),
                  ),
                );

            return (
              <span
                key={`${word}-${index}`}
                className="mr-2 inline-block lg:mr-3"
                style={{
                  opacity: 0.15 + progress * 0.85,
                  filter: `blur(${(1 - progress) * 8}px)`,
                  transition: "opacity 75ms, filter 75ms",
                }}
              >
                {word}
              </span>
            );
          })}
        </p>
      </div>
    </section>
  );
}
