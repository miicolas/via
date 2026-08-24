"use client";

import { TransitText } from "@/components/ui/transit-text";
import type { FAQContent } from "@/constants/types";
import { MARKETING_EASE } from "@/lib/motion";
import { AnimatePresence, motion } from "motion/react";
import { ChevronDown } from "lucide-react";
import { useState, type ReactNode } from "react";

interface AccordionProps {
  readonly items: readonly FAQContent[];
  readonly defaultOpenIndex?: number | null;
}

export function Accordion({
  items,
  defaultOpenIndex = 0,
}: AccordionProps): ReactNode {
  const [openIndex, setOpenIndex] = useState<number | null>(defaultOpenIndex);

  return (
    <div className="flex flex-col gap-3" role="list">
      {items.map((item, index) => {
        const isOpen = openIndex === index;

        return (
          <motion.div
            key={item.question}
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-50px" }}
            transition={{
              duration: 0.5,
              ease: MARKETING_EASE,
              delay: index * 0.05,
            }}
            className="rounded-2xl bg-frame px-5 shadow-sm sm:px-6"
            role="listitem"
          >
            <button
              type="button"
              onClick={() => setOpenIndex(isOpen ? null : index)}
              className="flex min-h-11 w-full cursor-pointer items-center justify-between gap-4 py-5 text-left sm:py-6"
              aria-expanded={isOpen}
            >
              <span className="text-base font-medium text-foreground sm:text-lg">
                {item.question}
              </span>
              <motion.span
                animate={{ rotate: isOpen ? 180 : 0 }}
                transition={{ duration: 0.3, ease: MARKETING_EASE }}
                className="shrink-0"
              >
                <ChevronDown
                  className="h-5 w-5 text-muted-foreground"
                  aria-hidden="true"
                />
              </motion.span>
            </button>
            <AnimatePresence initial={false}>
              {isOpen && (
                <motion.div
                  initial={{ height: 0, opacity: 0 }}
                  animate={{ height: "auto", opacity: 1 }}
                  exit={{ height: 0, opacity: 0 }}
                  transition={{ duration: 0.3, ease: MARKETING_EASE }}
                  className="overflow-hidden"
                >
                  <p className="pb-5 text-sm leading-relaxed text-muted-foreground sm:pb-6 sm:text-base">
                    <TransitText>{item.answer}</TransitText>
                  </p>
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>
        );
      })}
    </div>
  );
}
