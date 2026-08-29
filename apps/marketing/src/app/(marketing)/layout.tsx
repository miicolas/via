import { SiteLayout } from "@/components/layout/site-layout";
import type { ReactNode } from "react";

export default function MarketingLayout({
  children,
}: {
  readonly children: ReactNode;
}): ReactNode {
  return <SiteLayout>{children}</SiteLayout>;
}
