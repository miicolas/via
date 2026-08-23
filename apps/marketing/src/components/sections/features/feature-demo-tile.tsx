import { Reveal } from "@/components/ui/reveal";
import type { ReactNode } from "react";

interface FeatureDemoTileProps {
  readonly title: string;
  readonly hint?: string;
  readonly index: number;
  readonly variant?: "secondary" | "primary";
  readonly className?: string;
  readonly children: ReactNode;
}

export function FeatureDemoTile({
  title,
  hint,
  index,
  variant = "secondary",
  className = "",
  children,
}: FeatureDemoTileProps): ReactNode {
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
        {hint ? (
          <p
            className={`mt-1.5 text-sm ${primary ? "text-white/70" : "text-card-foreground-muted"}`}
          >
            {hint}
          </p>
        ) : null}
      </div>
      <div className="flex flex-1 items-center justify-center pt-8">
        <div className="w-full max-w-md">{children}</div>
      </div>
    </Reveal>
  );
}
