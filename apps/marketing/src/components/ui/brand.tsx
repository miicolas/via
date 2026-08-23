import type { LogoAsset } from "@/constants/types";
import Image from "next/image";
import type { ReactNode } from "react";

interface BrandProps {
  readonly name: string;
  readonly href: string;
  readonly logo: LogoAsset;
  readonly inverse?: boolean;
  readonly compactOnTablet?: boolean;
  readonly size?: "default" | "large";
}

export function Brand({
  name,
  href,
  logo,
  inverse = false,
  compactOnTablet = false,
  size = "default",
}: BrandProps): ReactNode {
  const textColor = inverse ? "text-white" : "text-foreground";
  const markSize = size === "large" ? "size-9" : "size-7";
  const textSize = size === "large" ? "text-xl" : "text-lg";

  return (
    <a
      href={href}
      className="flex items-center gap-2"
      aria-label={`${name}, accueil`}
    >
      <Image
        src={logo.src}
        alt=""
        width={64}
        height={64}
        className={`${markSize} rounded-[27%] shadow-sm`}
        aria-hidden="true"
        unoptimized
      />
      <span
        className={`${textSize} leading-none font-semibold ${textColor} ${compactOnTablet ? "max-[1200px]:hidden max-[850px]:inline" : ""}`}
      >
        {name}
      </span>
    </a>
  );
}
