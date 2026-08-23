"use client";

import type { PageContent } from "@/constants/page";
import { marketingMedia } from "@/constants/media";
import { motion, useMotionValue, useSpring } from "motion/react";
import { useRef, type MouseEvent, type ReactNode } from "react";
import { HeroCopy } from "./hero-copy";
import { ProductPreview } from "./product-preview";

const PARALLAX_INTENSITY = 20;

interface HeroSectionProps {
  readonly content: PageContent["hero"];
}

export function HeroSection({ content }: HeroSectionProps): ReactNode {
  const sectionRef = useRef<HTMLElement>(null);
  const mouseX = useMotionValue(0);
  const mouseY = useMotionValue(0);
  const x = useSpring(mouseX, { damping: 25, stiffness: 150 });
  const y = useSpring(mouseY, { damping: 25, stiffness: 150 });

  const handleMouseMove = (event: MouseEvent<HTMLElement>): void => {
    const section = sectionRef.current;
    if (!section || window.innerWidth < 850) return;

    const rect = section.getBoundingClientRect();
    const offsetX =
      (event.clientX - (rect.left + rect.width / 2)) / (rect.width / 2);
    const offsetY =
      (event.clientY - (rect.top + rect.height / 2)) / (rect.height / 2);
    mouseX.set(offsetX * PARALLAX_INTENSITY);
    mouseY.set(offsetY * PARALLAX_INTENSITY);
  };

  return (
    <section
      ref={sectionRef}
      className="relative flex flex-col"
      style={{ colorScheme: "light" }}
      onMouseMove={handleMouseMove}
      onMouseLeave={() => {
        mouseX.set(0);
        mouseY.set(0);
      }}
    >
      <motion.div
        className="absolute inset-0 -z-10 rounded-br-4xl rounded-bl-4xl bg-cover bg-center bg-no-repeat brightness-95 contrast-110 saturate-110 min-[850px]:inset-2.5 min-[850px]:scale-105"
        style={{
          backgroundImage: `linear-gradient(180deg,rgba(24,114,247,0.12) 0%,rgba(0,74,173,0.42) 100%),url(${marketingMedia.background.src})`,
          backgroundBlendMode: "multiply, normal",
          backgroundPosition: marketingMedia.background.position,
          x,
          y,
        }}
        aria-hidden="true"
      />
      <div className="flex items-start justify-center px-6 pt-64 max-[850px]:pt-32">
        <HeroCopy content={content} />
      </div>
      <ProductPreview preview={content.preview} />
    </section>
  );
}
