"use client";

import type { LinkItem, NavigationGroup } from "@/constants/types";
import { MARKETING_EASE } from "@/lib/motion";
import { SplitActionLink } from "@/components/ui/split-action-link";
import { AnimatePresence, motion } from "motion/react";
import { ChevronDown } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";

interface MobileNavigationProps {
  readonly open: boolean;
  readonly lead: LinkItem;
  readonly groups: readonly NavigationGroup[];
  // readonly pricing: LinkItem;
  readonly signIn: LinkItem;
  readonly primaryAction: LinkItem;
  readonly onClose: () => void;
}

export function MobileNavigation({
  open,
  lead,
  groups,
  // pricing,
  signIn,
  primaryAction,
  onClose,
}: MobileNavigationProps): ReactNode {
  const [expandedGroup, setExpandedGroup] = useState<string | null>(null);
  const panelRef = useRef<HTMLDivElement>(null);

  // Tab stays inside the header while the menu is open: past the last link it
  // wraps back to the hamburger, and Shift+Tab from the top wraps to the end.
  useEffect(() => {
    if (!open) return;

    const handleKeyDown = (event: KeyboardEvent): void => {
      if (event.key !== "Tab") return;
      const header = panelRef.current?.closest("header");
      if (!header) return;

      const focusable = [
        ...header.querySelectorAll<HTMLElement>(
          'a[href], button:not([disabled])',
        ),
      ].filter((element) => element.offsetParent !== null);
      const first = focusable[0];
      const last = focusable.at(-1);
      if (!first || !last) return;

      const active = document.activeElement;
      if (!event.shiftKey && active === last) {
        event.preventDefault();
        first.focus();
      } else if (event.shiftKey && (active === first || !header.contains(active))) {
        event.preventDefault();
        last.focus();
      }
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [open]);

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          id="mobile-navigation"
          ref={panelRef}
          initial={{ height: 0, opacity: 0 }}
          animate={{ height: "auto", opacity: 1 }}
          exit={{ height: 0, opacity: 0 }}
          transition={{ duration: 0.3, ease: MARKETING_EASE }}
          className="hidden overflow-hidden max-[850px]:block"
        >
          <div className="max-h-[calc(100dvh-5.5rem)] overflow-y-auto px-6 pb-4">
            <nav>
              <a
                href={lead.href}
                className="flex items-center justify-between border-b border-foreground/10 py-4 text-base font-medium text-foreground"
                onClick={onClose}
              >
                {lead.label}
              </a>
              {groups.map((group) => {
                const expanded = expandedGroup === group.label;
                return (
                  <div
                    key={group.label}
                    className="border-b border-foreground/10"
                  >
                    <button
                      type="button"
                      className="flex w-full items-center justify-between py-4 text-base font-medium text-foreground"
                      onClick={() =>
                        setExpandedGroup(expanded ? null : group.label)
                      }
                      aria-expanded={expanded}
                    >
                      {group.label}
                      <motion.span
                        animate={{ rotate: expanded ? 180 : 0 }}
                        transition={{ duration: 0.2 }}
                      >
                        <ChevronDown
                          className="h-5 w-5 text-muted-foreground"
                          aria-hidden="true"
                        />
                      </motion.span>
                    </button>
                    <AnimatePresence initial={false}>
                      {expanded && (
                        <motion.div
                          initial={{ height: 0, opacity: 0 }}
                          animate={{ height: "auto", opacity: 1 }}
                          exit={{ height: 0, opacity: 0 }}
                          transition={{ duration: 0.2 }}
                          className="overflow-hidden"
                        >
                          <div className="space-y-1 pb-2">
                            {group.items.map((item) => (
                              <a
                                key={item.label}
                                href={item.href}
                                className="block py-3 text-sm text-foreground/80 hover:text-foreground"
                                onClick={onClose}
                              >
                                {item.label}
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
                className="flex items-center justify-between py-4 text-base font-medium text-foreground"
                onClick={onClose}
              >
                {pricing.label}
              </a> */}
            </nav>

            <div className="flex items-center justify-between pt-8 pb-2">
              <a
                href={signIn.href}
                className="inline-flex min-h-11 items-center text-base font-medium text-foreground"
                onClick={onClose}
              >
                {signIn.label}
              </a>
              <SplitActionLink {...primaryAction} onClick={onClose} />
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
