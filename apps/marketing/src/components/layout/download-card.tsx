import type { PageContent } from "@/constants/page";
import { marketingMedia } from "@/constants/media";
import { LaunchAction } from "@/components/ui/launch-action";
import type { ReactNode } from "react";

export function DownloadCard({
  content,
}: {
  readonly content: PageContent["footer"];
}): ReactNode {
  return (
    <div
      id="download"
      className="absolute top-0 left-1/2 w-full max-w-5xl -translate-x-1/2 scroll-mt-32"
    >
      <div className="relative w-full overflow-hidden rounded-3xl shadow-2xl/15">
        <div
          className="absolute inset-0 scale-110 bg-center bg-no-repeat blur-[2px] brightness-95 contrast-110 saturate-110"
          style={{
            backgroundImage: `linear-gradient(180deg,rgba(24,114,247,0.16),rgba(0,74,173,0.46)),url(${marketingMedia.background.src})`,
            backgroundBlendMode: "multiply, normal",
            backgroundPosition: marketingMedia.background.position,
            backgroundSize: "cover",
          }}
          aria-hidden="true"
        />
        <div className="relative z-10 flex flex-col items-center gap-14 px-12 py-24 text-center max-[850px]:gap-8 max-[850px]:px-6 max-[850px]:pt-12 max-[850px]:pb-6">
          <h2 className="max-w-xl text-5xl leading-[1.05] font-medium tracking-tight text-balance text-black max-[850px]:text-3xl">
            {content.headline}
          </h2>
          <LaunchAction configuration={content.action} mode="button" tone="dark" />
        </div>
      </div>
    </div>
  );
}
