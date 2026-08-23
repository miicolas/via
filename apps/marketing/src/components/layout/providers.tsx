"use client";

import { project } from "@/constants/project";
import { ReducedMotionProvider } from "@/lib/motion";
import { ThemeProvider } from "next-themes";
import type { ReactNode } from "react";
import { SmoothScroll } from "./smooth-scroll";

export function Providers({
  children,
}: {
  readonly children: ReactNode;
}): ReactNode {
  return (
    <ThemeProvider
      attribute="class"
      defaultTheme={project.theme.defaultTheme}
      enableSystem={project.theme.enableSystemTheme}
      disableTransitionOnChange
    >
      <ReducedMotionProvider>
        <SmoothScroll>{children}</SmoothScroll>
      </ReducedMotionProvider>
    </ThemeProvider>
  );
}
