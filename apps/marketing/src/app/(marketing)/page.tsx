import { BlurHeadlineSection } from "@/components/sections/blur-headline-section";
import { FAQSection } from "@/components/sections/faq/faq-section";
import { ExpansionSection } from "@/components/sections/expansion/expansion-section";
import { FeaturesSection } from "@/components/sections/features/features-section";
import { HeroSection } from "@/components/sections/hero/hero-section";
// import { PricingSection } from "@/components/sections/pricing/pricing-section";
import { JourneyMomentsSection } from "@/components/sections/journey-moments/journey-moments-section";
import { frequentlyAskedQuestions } from "@/constants/faq";
import { featureContent } from "@/constants/features";
import { journeyMoments } from "@/constants/journey-moments";
import { pageContent } from "@/constants/page";
// import { pricingPlans } from "@/constants/pricing";
import { project } from "@/constants/project";
import { createPageMetadata } from "@/lib/metadata";
import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = createPageMetadata({
  title: pageContent.metadata.title,
  description: `Welcome to ${project.metadata.name}. ${project.metadata.description}`,
});

export default function MarketingPage(): ReactNode {
  return (
    <main id="main-content" className="flex-1">
      <HeroSection content={pageContent.hero} />
      <BlurHeadlineSection text={pageContent.blurHeadline} />
      <FeaturesSection content={featureContent} />
      <JourneyMomentsSection
        {...pageContent.journeyMoments}
        moments={journeyMoments}
      />
      <ExpansionSection />
      {/* Pricing is hidden until Via has plans to present. */}
      {/* <PricingSection content={pageContent.pricing} plans={pricingPlans} /> */}
      <FAQSection content={pageContent.faq} items={frequentlyAskedQuestions} />
    </main>
  );
}
