"use client";

import { project } from "@/constants/project";
import { ReducedMotionProvider } from "@/lib/motion";
import { ThemeProvider } from "next-themes";
import type { ReactNode } from "react";
import { SmoothScroll } from "./smooth-scroll";

/**
 * Ce que toute page du site a besoin de savoir : son thème, le respect du
 * mouvement réduit, le défilement. Ce qu’une seule route consomme — React Query
 * et nuqs — est monté par cette route, dans `app/trip/[token]/providers.tsx`.
 */
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
