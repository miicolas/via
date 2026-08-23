import { Reveal } from "@/components/ui/reveal";
import type { CallToAction } from "@/constants/types";
import { ArrowRight } from "lucide-react";
import type { ReactNode } from "react";

interface ParticipationTileProps {
  readonly title: string;
  readonly hint: string;
  readonly index: number;
  readonly variant?: "secondary" | "primary";
  readonly action?: CallToAction;
  readonly className?: string;
  readonly children: ReactNode;
}

/** Une carte du bento communauté, dans la même grammaire que les tuiles de la page d’accueil. */
export function ParticipationTile({
  title,
  hint,
  index,
  variant = "secondary",
  action,
  className = "",
  children,
}: ParticipationTileProps): ReactNode {
  const primary = variant === "primary";

  return (
    <Reveal
      distance={30}
      duration={0.7}
      delay={index * 0.08}
      margin="-80px"
      className={`group flex min-h-80 flex-col overflow-hidden rounded-4xl p-6 md:p-8 ${primary ? "bg-card-primary" : "bg-card-secondary"} ${className}`}
    >
      <div>
        <h3
          className={`text-xl leading-tight font-medium md:text-2xl ${primary ? "text-white" : "text-card-foreground"}`}
        >
          {title}
        </h3>
        <p
          className={`mt-1.5 text-sm ${primary ? "text-white/70" : "text-card-foreground-muted"}`}
        >
          {hint}
        </p>
      </div>
      <div className="flex flex-1 items-center justify-center py-8">
        <div className="w-full max-w-md transition-transform duration-500 ease-out group-hover:scale-[1.02]">
          {children}
        </div>
      </div>
      {action ? (
        <a
          href={action.href}
          className={`focus-ring inline-flex min-h-11 items-center gap-2 self-start rounded-lg text-sm font-semibold ${primary ? "text-white hover:text-white/80" : "text-foreground hover:text-accent"}`}
        >
          {action.label}
          <ArrowRight
            className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-0.5"
            aria-hidden="true"
          />
        </a>
      ) : null}
    </Reveal>
  );
}
