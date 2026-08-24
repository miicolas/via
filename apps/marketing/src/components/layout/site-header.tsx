"use client";

import { navigation } from "@/constants/navigation";
import { project } from "@/constants/project";
import { MARKETING_EASE, useReducedMotion } from "@/lib/motion";
import { Brand } from "@/components/ui/brand";
import { SplitActionLink } from "@/components/ui/split-action-link";
import { motion } from "motion/react";
import { useEffect, useState, type ReactNode } from "react";
import { DesktopNavigation } from "./desktop-navigation";
import { HamburgerIcon } from "./hamburger-icon";
import { HeaderCorner } from "./header-corner";
import { MobileNavigation } from "./mobile-navigation";

export function SiteHeader(): ReactNode {
  const [activeGroup, setActiveGroup] = useState<string | null>(null);
  const [mobileOpen, setMobileOpen] = useState(false);
  const reduceMotion = useReducedMotion();

  // The page must not scroll behind the open menu, and Escape must close it.
  useEffect(() => {
    if (!mobileOpen) return;

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    const handleKeyDown = (event: KeyboardEvent): void => {
      if (event.key === "Escape") setMobileOpen(false);
    };
    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.body.style.overflow = previousOverflow;
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [mobileOpen]);

  return (
    <motion.header
      initial={reduceMotion ? false : { y: -100 }}
      animate={{ y: 0 }}
      transition={{ duration: 0.5, ease: MARKETING_EASE }}
      className="fixed top-2.5 left-1/2 z-9998 w-full max-w-5xl -translate-x-1/2 rounded-b-4xl bg-frame shadow-2xl/20 max-[1200px]:max-w-2xl max-[850px]:top-0 max-[850px]:right-0 max-[850px]:left-0 max-[850px]:w-full max-[850px]:max-w-none max-[850px]:translate-x-0 max-[850px]:overflow-hidden max-[850px]:rounded-none max-[850px]:rounded-b-4xl"
    >
      <div className="flex h-20 items-center justify-between px-4 max-[850px]:h-18 max-[850px]:px-6">
        <div className="ml-4 max-[850px]:ml-0">
          <Brand
            name={project.brand.name}
            href={project.brand.homeHref}
            logo={project.brand.logo}
            compactOnTablet
          />
        </div>

        <DesktopNavigation
          groups={navigation.groups}
          // pricing={navigation.pricing}
          activeGroup={activeGroup}
          onActiveGroupChange={setActiveGroup}
        />

        <div className="flex items-center gap-4 max-[850px]:hidden">
          <a
            href={navigation.signIn.href}
            className="text-sm font-medium text-foreground/80 transition-colors hover:text-foreground"
          >
            {navigation.signIn.label}
          </a>
          <SplitActionLink {...navigation.primaryAction} />
        </div>

        <button
          type="button"
          className="hidden h-11 w-11 items-center justify-center max-[850px]:flex"
          onClick={() => setMobileOpen((current) => !current)}
          aria-label={mobileOpen ? "Fermer le menu" : "Ouvrir le menu"}
          aria-expanded={mobileOpen}
          aria-controls="mobile-navigation"
        >
          <HamburgerIcon open={mobileOpen} />
        </button>
      </div>

      <MobileNavigation
        open={mobileOpen}
        lead={navigation.mobileLead}
        groups={navigation.groups}
        // pricing={navigation.pricing}
        signIn={navigation.signIn}
        primaryAction={navigation.primaryAction}
        onClose={() => setMobileOpen(false)}
      />

      <HeaderCorner className="pointer-events-none absolute top-0 -left-12.25 rotate-180 text-frame max-[850px]:hidden" />
      <HeaderCorner className="pointer-events-none absolute top-0 -right-12.25 rotate-90 text-frame max-[850px]:hidden" />
    </motion.header>
  );
}
