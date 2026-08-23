import { BlurHeadlineSection } from "@/components/sections/blur-headline-section";
import { CommunityCtaSection } from "@/components/sections/community/community-cta-section";
import { CommunityHero } from "@/components/sections/community/community-hero";
import { CommunityParticipationSection } from "@/components/sections/community/community-participation-section";
import { CommunityPathSection } from "@/components/sections/community/community-path-section";
import { communityContent } from "@/constants/community-page";
import { createPageMetadata } from "@/lib/metadata";
import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = createPageMetadata({
  title: communityContent.metadata.title,
  description: communityContent.metadata.description,
  path: "/community",
});

export default function CommunityPage(): ReactNode {
  return (
    <main id="main-content" className="flex-1">
      <CommunityHero content={communityContent.hero} />
      <BlurHeadlineSection text={communityContent.blurHeadline} />
      <CommunityParticipationSection content={communityContent.participation} />
      <CommunityPathSection content={communityContent.path} />
      <CommunityCtaSection content={communityContent.cta} />
    </main>
  );
}
