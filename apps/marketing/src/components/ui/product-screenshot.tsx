import type { ScreenshotAsset } from "@/constants/screenshots";
import Image from "next/image";
import type { ReactNode } from "react";

interface ProductScreenshotProps {
  readonly asset: ScreenshotAsset;
  readonly className?: string;
  readonly imageClassName?: string;
  readonly priority?: boolean;
  readonly sizes?: string;
}

export function ProductScreenshot({
  asset,
  className = "",
  imageClassName = "",
  priority = false,
  sizes = "(max-width: 768px) 70vw, 360px",
}: ProductScreenshotProps): ReactNode {
  return (
    <div
      className={`relative overflow-hidden rounded-[3rem] border-[5px] border-neutral-900 bg-neutral-950 shadow-2xl ${className}`}
    >
      <Image
        src={asset.src}
        alt={asset.alt}
        width={asset.width}
        height={asset.height}
        className={`h-auto w-full ${imageClassName}`}
        priority={priority}
        sizes={sizes}
      />
    </div>
  );
}
