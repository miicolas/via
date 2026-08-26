import { LineBadge } from "@/components/ui/line-badge";
import { TransitText } from "@/components/ui/transit-text";
import { transitLines } from "@/constants/transit";
import type { LineCondition } from "@/lib/lines";
import type { CSSProperties, ReactNode } from "react";

const conditionLabels: Record<LineCondition["condition"], string> = {
  normal: "Trafic normal",
  attention: "Trafic perturbé par endroits",
  disrupted: "Trafic perturbé",
  suspended: "Trafic interrompu",
};

const conditionAccents: Record<LineCondition["condition"], string> = {
  normal: "#16a34a",
  attention: "#d97706",
  disrupted: "#d97706",
  suspended: "#dc2626",
};

/**
 * L’état réel de la ligne, maintenant.
 *
 * Ne s’affiche que si l’API a répondu. C’est volontaire et c’est tout le
 * contrat : l’article est écrit pour être juste sans ce bloc, et ce bloc n’est
 * là que pour dire ce qu’un texte daté ne peut pas savoir. Une API endormie
 * coûte donc un bandeau, jamais une page.
 */
export function LiveLineStatus({
  line,
  condition,
}: {
  readonly line: keyof typeof transitLines;
  readonly condition: LineCondition | null;
}): ReactNode {
  if (!condition) return null;

  const reference = transitLines[line];

  return (
    <div
      className="flex flex-wrap items-center gap-x-4 gap-y-2 rounded-2xl border border-foreground/10 px-4 py-3"
      style={{ "--condition": conditionAccents[condition.condition] } as CSSProperties}
    >
      <LineBadge line={reference} className="size-8 rounded-[0.55rem] text-sm" />

      <p className="flex items-center gap-2 font-medium">
        <span className="size-2 rounded-full bg-[var(--condition)]" aria-hidden="true" />
        {conditionLabels[condition.condition]}
      </p>

      {condition.summary !== undefined && (
        <p className="w-full text-sm leading-6 text-muted-foreground">
          <TransitText>{condition.summary}</TransitText>
        </p>
      )}
    </div>
  );
}
