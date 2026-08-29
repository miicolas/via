import { footerNavigation } from "@/constants/navigation";
import { pageContent } from "@/constants/page";
import { project } from "@/constants/project";
import type { ReactNode } from "react";
import { SkipToContent } from "../ui/skip-to-content";
import { ThemeSwitch } from "../ui/theme-switch";
import { SiteFooter } from "./site-footer";
import { SiteFrame } from "./site-frame";
import { SiteHeader } from "./site-header";

/** The public-site chrome shared by editorial pages and shared journeys. */
export function SiteLayout({
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
