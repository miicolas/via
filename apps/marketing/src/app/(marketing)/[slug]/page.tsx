import { MarketingDetailPage } from "@/components/marketing/marketing-detail-page";
import {
  getMarketingPage,
  marketingPageSlugs,
} from "@/constants/marketing-pages";
import { createPageMetadata } from "@/lib/metadata";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import type { ReactNode } from "react";

interface MarketingDetailRouteProps {
  readonly params: Promise<{ slug: string }>;
}

export function generateStaticParams(): { slug: string }[] {
  return marketingPageSlugs.map((slug) => ({ slug }));
}

export async function generateMetadata({
  params,
}: MarketingDetailRouteProps): Promise<Metadata> {
  const { slug } = await params;
  const page = getMarketingPage(slug);

  if (!page) return {};

  return createPageMetadata({
    title: page.eyebrow,
    description: page.description,
    path: `/${page.slug}`,
  });
}

export default async function MarketingDetailRoute({
  params,
}: MarketingDetailRouteProps): Promise<ReactNode> {
  const { slug } = await params;
  const page = getMarketingPage(slug);

  if (!page) notFound();

  return <MarketingDetailPage page={page} />;
}
