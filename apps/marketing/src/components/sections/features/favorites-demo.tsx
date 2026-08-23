"use client";

import type { FeaturesContent } from "@/constants/features";
import {
  BriefcaseBusiness,
  Dumbbell,
  GraduationCap,
  House,
  Plus,
} from "lucide-react";
import {
  AnimatePresence,
  motion,
  Reorder,
  useReducedMotion,
} from "motion/react";
import { useState, type ReactNode } from "react";

const ICONS = {
  house: House,
  briefcase: BriefcaseBusiness,
  dumbbell: Dumbbell,
  graduation: GraduationCap,
} as const;
const POP = { type: "spring", bounce: 0.3, duration: 0.45 } as const;

export function FavoritesDemo({
  content,
}: {
  readonly content: FeaturesContent["highlights"]["favorites"];
}): ReactNode {
  const reduceMotion = useReducedMotion();
  const baseIds = content.chips.map((chip) => chip.id);
  const [order, setOrder] = useState<string[]>(baseIds);

  const chipById = new Map<
    string,
    { readonly label: string; readonly icon: keyof typeof ICONS }
  >([...content.chips, ...content.extras].map((chip) => [chip.id, chip]));
  const allAdded = content.extras.every((extra) => order.includes(extra.id));

  const handleAdd = (): void => {
    if (allAdded) {
      setOrder(baseIds);
      return;
    }
    const next = content.extras.find((extra) => !order.includes(extra.id));
    if (next) setOrder((current) => [...current, next.id]);
  };

  return (
    <div className="flex flex-wrap items-center justify-center gap-3 rounded-[1.75rem] border border-black/8 bg-white/94 p-5 shadow-[0_24px_70px_rgba(0,0,0,0.14)]">
      <Reorder.Group
        axis="x"
        values={order}
        onReorder={setOrder}
        className="flex list-none flex-wrap items-center justify-center gap-2.5"
      >
        <AnimatePresence initial={false}>
          {order.map((id) => {
            const chip = chipById.get(id);
            if (!chip) return null;
            const Icon = ICONS[chip.icon];
            const isPrimary = order[0] === id;

            return (
              <Reorder.Item
                key={id}
                value={id}
                initial={reduceMotion ? false : { scale: 0.6, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                exit={reduceMotion ? { opacity: 0 } : { scale: 0.6, opacity: 0 }}
                whileDrag={reduceMotion ? {} : { scale: 1.08 }}
                whileTap={reduceMotion ? {} : { scale: 0.95 }}
                transition={reduceMotion ? { duration: 0 } : POP}
                className={`flex cursor-grab items-center gap-2 rounded-full px-4 py-2.5 text-base font-semibold select-none active:cursor-grabbing ${
                  isPrimary
                    ? "bg-[#e8f1ff] text-[#1872f7]"
                    : "bg-neutral-100 text-neutral-950"
                }`}
                aria-label={`${chip.label}${isPrimary ? ", raccourci principal" : ""}. Glisser pour réorganiser`}
              >
                <Icon className="size-5" strokeWidth={2} aria-hidden="true" />
                {chip.label}
              </Reorder.Item>
            );
          })}
        </AnimatePresence>
      </Reorder.Group>
      <motion.button
        type="button"
        onClick={handleAdd}
        whileTap={reduceMotion ? {} : { scale: 0.9 }}
        transition={reduceMotion ? { duration: 0 } : POP}
        className="grid size-11 shrink-0 cursor-pointer place-items-center rounded-full bg-[#1872f7] text-white"
        aria-label={
          allAdded ? "Réinitialiser les adresses" : "Ajouter une adresse"
        }
      >
        <motion.span
          className="grid place-items-center"
          animate={{ rotate: allAdded ? 45 : 0 }}
          transition={reduceMotion ? { duration: 0 } : POP}
          aria-hidden="true"
        >
          <Plus className="size-5" strokeWidth={2.4} />
        </motion.span>
      </motion.button>
    </div>
  );
}
