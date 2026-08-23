import { SiteFrame } from "@/components/layout/site-frame";
import { SiteFooter } from "@/components/layout/site-footer";
import { SiteHeader } from "@/components/layout/site-header";
import { SkipToContent } from "@/components/ui/skip-to-content";
import { ThemeSwitch } from "@/components/ui/theme-switch";
import { footerNavigation } from "@/constants/navigation";
import { pageContent } from "@/constants/page";
import { project } from "@/constants/project";
import type { ReactNode } from "react";

export default function MarketingLayout({
  children,
}: {
  readonly children: ReactNode;
}): ReactNode {
  return (
    <>
      <SiteFrame />
      <SiteHeader />
      <ThemeSwitch />
      <SkipToContent />
      {children}
      <SiteFooter
        brand={project.brand}
        content={pageContent.footer}
        navigation={footerNavigation}
      />
    </>
  );
}
