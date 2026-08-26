import type { AlertVariant } from "@/lib/blog/remark-transit";
import {
  BusFront,
  Construction,
  Info,
  Lightbulb,
  TriangleAlert,
  type LucideIcon,
} from "lucide-react";
import type { CSSProperties, ReactNode } from "react";

interface VariantStyle {
  readonly label: string;
  readonly icon: LucideIcon;
  /** Teinte unique : elle porte la bordure et le pictogramme, jamais le texte. */
  readonly accent: string;
}

/**
 * Le vocabulaire du réseau, pas celui d’un dépôt de code.
 *
 * Le libellé n’est pas décoratif : il est lu à voix haute par les lecteurs
 * d’écran, pour qui la couleur et le pictogramme n’existent pas. « Travaux »
 * dit ce que le jaune dit à l’œil.
 */
const variants: Record<AlertVariant, VariantStyle> = {
  travaux: { label: "Travaux", icon: Construction, accent: "#d97706" },
  perturbation: { label: "Perturbation", icon: TriangleAlert, accent: "#dc2626" },
  substitution: { label: "Substitution", icon: BusFront, accent: "#0891b2" },
  note: { label: "À noter", icon: Info, accent: "var(--accent)" },
  astuce: { label: "Astuce", icon: Lightbulb, accent: "#16a34a" },
};

/**
 * Un encadré typé dans le corps d’un article.
 *
 * Le fond est un `color-mix` de la teinte avec du transparent plutôt qu’une
 * couleur figée : le même encadré se pose sur le fond clair comme sur le fond
 * sombre sans qu’aucune des deux variantes n’ait à être écrite.
 */
export function AlertCallout({
  variant = "note",
  children,
}: {
  readonly variant?: AlertVariant;
  readonly children: ReactNode;
}): ReactNode {
  const style = variants[variant] ?? variants.note;
  const Icon = style.icon;

  return (
    <aside
      className="my-8 rounded-2xl border-l-2 border-[var(--alert)] bg-[color-mix(in_srgb,var(--alert)_7%,transparent)] py-5 pr-5 pl-5"
      style={{ "--alert": style.accent } as CSSProperties}
    >
      <p className="flex items-center gap-2 text-xs font-semibold tracking-[0.08em] uppercase">
        <Icon className="size-4 shrink-0 text-[var(--alert)]" aria-hidden="true" />
        <span className="text-[var(--alert)]">{style.label}</span>
      </p>
      <div className="mt-2 space-y-3 leading-7 text-foreground/90 [&>p:first-child]:mt-0 [&>p:last-child]:mb-0">
        {children}
      </div>
    </aside>
  );
}
