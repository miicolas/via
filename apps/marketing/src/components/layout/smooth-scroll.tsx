"use client";

import { project } from "@/constants/project";
import Lenis from "lenis";
import { useEffect, type ReactNode } from "react";

const LENIS_OPTIONS = {
  duration: 1.6,
  easing: (value: number) => Math.min(1, 1.001 - 2 ** (-10 * value)),
  orientation: "vertical" as const,
  gestureOrientation: "vertical" as const,
  smoothWheel: true,
  wheelMultiplier: 1,
  touchMultiplier: 2,
};

export function SmoothScroll({
  children,
}: {
  readonly children: ReactNode;
}): ReactNode {
  useEffect(() => {
    if (!project.features.smoothScroll) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const lenis = new Lenis(LENIS_OPTIONS);
    let frame: number;

    const animate = (time: number): void => {
      lenis.raf(time);
      frame = requestAnimationFrame(animate);
    };

    const handleAnchorClick = (event: MouseEvent): void => {
      const target = event.target as HTMLElement;
      const anchor = target.closest<HTMLAnchorElement>('a[href^="#"]');
      const href = anchor?.getAttribute("href");
      if (!href || href === "#") return;

      const element = document.querySelector<HTMLElement>(href);
      if (!element) return;

      event.preventDefault();
      lenis.scrollTo(element, { offset: -100 });
    };

    frame = requestAnimationFrame(animate);
    document.addEventListener("click", handleAnchorClick);

    return () => {
      cancelAnimationFrame(frame);
      document.removeEventListener("click", handleAnchorClick);
      lenis.destroy();
    };
  }, []);

  return children;
}
