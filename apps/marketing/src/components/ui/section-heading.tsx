import { Reveal } from "./reveal";
import type { ReactNode } from "react";

interface SectionHeadingProps {
  readonly eyebrow: string;
  readonly title: string;
  readonly description: string;
  readonly width?: "narrow" | "wide";
}

export function SectionHeading({
  eyebrow,
  title,
  description,
  width = "narrow",
}: SectionHeadingProps): ReactNode {
  return (
    <Reveal className="mb-12 text-center sm:mb-16">
      <span className="text-sm font-medium text-muted-foreground">
        {eyebrow}
      </span>
      <h2 className="mt-3 text-3xl font-semibold tracking-tight text-foreground sm:text-4xl lg:text-5xl">
        {title}
      </h2>
      <p
        className={`mx-auto mt-4 text-base text-muted-foreground sm:text-lg ${width === "wide" ? "max-w-2xl" : "max-w-xl"}`}
      >
        {description}
      </p>
    </Reveal>
  );
}
