import type { PageContent } from "@/constants/page";
import type { BrandContent, FooterGroup } from "@/constants/types";
import { Brand } from "@/components/ui/brand";
import type { ReactNode } from "react";
import { DownloadCard } from "./download-card";
import { FooterLinkGroup } from "./footer-link-group";

interface SiteFooterProps {
  readonly brand: BrandContent;
  readonly content: PageContent["footer"];
  readonly navigation: readonly FooterGroup[];
}

export function SiteFooter({
  brand,
  content,
  navigation,
}: SiteFooterProps): ReactNode {
  return (
    <footer className="relative mx-2.5 mt-24 pt-38 max-[850px]:mx-0">
      <DownloadCard content={content} />
      <div className="rounded-tl-[3rem] rounded-tr-[3rem] bg-accent pt-96 pb-16 max-[850px]:pt-56">
        <div className="mx-auto max-w-5xl px-6">
          <div className="flex items-start justify-between gap-12 max-[850px]:flex-col max-[850px]:gap-10">
            <Brand
              name={brand.name}
              href={brand.homeHref}
              logo={brand.logo}
              inverse
              size="large"
            />
            <nav
              className="flex gap-16 max-[850px]:flex-wrap max-[850px]:gap-10"
              aria-label="Footer navigation"
            >
              {navigation.map((group) => (
                <FooterLinkGroup key={group.label} group={group} />
              ))}
            </nav>
          </div>
          <div className="mt-16 pt-6">
            <p className="text-center text-sm text-white/70">
              © {new Date().getFullYear()} {brand.name}. {content.copyright}
            </p>
          </div>
        </div>
      </div>
    </footer>
  );
}
