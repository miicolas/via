"use client";

import type { NavigationGroup } from "@/constants/types";
import { MARKETING_EASE } from "@/lib/motion";
import { AnimatePresence, motion } from "motion/react";
import { ChevronDown } from "lucide-react";
import type { ReactNode } from "react";

interface DesktopNavigationProps {
  readonly groups: readonly NavigationGroup[];
  // readonly pricing: LinkItem;
  readonly activeGroup: string | null;
  readonly onActiveGroupChange: (label: string | null) => void;
}

export function DesktopNavigation({
  groups,
  // pricing,
  activeGroup,
  onActiveGroupChange,
}: DesktopNavigationProps): ReactNode {
  return (
    <nav className="flex items-center gap-1 max-[1200px]:gap-0 max-[850px]:hidden">
      {groups.map((group) => {
        const open = activeGroup === group.label;
        return (
          <div
            key={group.label}
            className="relative"
            onMouseEnter={() => onActiveGroupChange(group.label)}
            onMouseLeave={() => onActiveGroupChange(null)}
          >
            <button
              type="button"
              // Hover opens on desktop; the click keeps the menu reachable on
              // tablets, where the header is still in its desktop layout.
              onClick={() => onActiveGroupChange(open ? null : group.label)}
              className="flex items-center gap-1 rounded-full px-4 py-2 text-sm font-medium text-foreground/80 transition-colors hover:bg-foreground/5 hover:text-foreground max-[1200px]:px-3"
              aria-expanded={open}
              aria-haspopup="true"
            >
              {group.label}
              <ChevronDown className="h-4 w-4" aria-hidden="true" />
            </button>
            <AnimatePresence>
              {open && (
                <motion.div
                  initial={{ opacity: 0, y: 8, scale: 0.96 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: 8, scale: 0.96 }}
                  transition={{ duration: 0.2, ease: MARKETING_EASE }}
                  className="absolute top-full left-0 w-72 pt-2"
                >
                  <div className="overflow-hidden rounded-2xl border border-border bg-frame p-2 shadow-lg">
                    {group.items.map((item) => (
                      <a
                        key={item.label}
                        href={item.href}
                        className="block rounded-xl px-4 py-3 transition-colors hover:bg-muted"
                      >
                        <span className="block text-sm font-medium text-foreground">
                          {item.label}
                        </span>
                        <span className="mt-0.5 block text-xs text-muted-foreground">
                          {item.description}
                        </span>
                      </a>
                    ))}
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        );
      })}
      {/* Pricing is hidden until Via has plans to present. */}
      {/* <a
        href={pricing.href}
        className="rounded-full px-4 py-2 text-sm font-medium text-foreground/80 transition-colors hover:bg-foreground/5 hover:text-foreground max-[1200px]:px-3"
      >
        {pricing.label}
      </a> */}
    </nav>
  );
}
