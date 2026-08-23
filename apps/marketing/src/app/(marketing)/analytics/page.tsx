import { AnalyticsDownloadSection } from "@/components/sections/analytics/analytics-download-section";
import { AnalyticsHero } from "@/components/sections/analytics/analytics-hero";
import { DataSourcesSection } from "@/components/sections/analytics/data-sources-section";
import { ElevatorSection } from "@/components/sections/analytics/elevator-section";
import { PeakHoursSection } from "@/components/sections/analytics/peak-hours-section";
import { BlurHeadlineSection } from "@/components/sections/blur-headline-section";
import { analyticsContent } from "@/constants/analytics-page";
import { createPageMetadata } from "@/lib/metadata";
import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = createPageMetadata({
  title: analyticsContent.metadata.title,
  description: analyticsContent.metadata.description,
  path: "/analytics",
});

export default function AnalyticsPage(): ReactNode {
  return (
    <main id="main-content" className="flex-1">
      <AnalyticsHero content={analyticsContent.hero} />
      <BlurHeadlineSection text={analyticsContent.blurHeadline} />
      <PeakHoursSection content={analyticsContent.peak} />
      <ElevatorSection content={analyticsContent.elevators} />
      <DataSourcesSection content={analyticsContent.sources} />
      <AnalyticsDownloadSection content={analyticsContent.download} />
    </main>
  );
}
