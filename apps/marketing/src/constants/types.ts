export interface LinkItem {
  readonly label: string;
  readonly href: string;
}

export interface DescribedLink extends LinkItem {
  readonly description: string;
}

export interface NavigationGroup {
  readonly label: string;
  readonly items: readonly DescribedLink[];
}

export interface FooterGroup {
  readonly label: string;
  readonly items: readonly LinkItem[];
}

export type CallToAction = LinkItem;

export interface LogoAsset {
  readonly name: string;
  readonly src: string;
}

export interface BrandContent {
  readonly name: string;
  readonly homeHref: string;
  readonly logo: LogoAsset;
}

export interface BrandContent {
  readonly name: string;
  readonly homeHref: string;
  readonly logo: LogoAsset;
}

export interface FeatureCardContent {
  readonly title: string;
  readonly description: string;
}

export interface ProcessStepContent extends FeatureCardContent {
  readonly icon: "calendar-check" | "users" | "rocket";
}

export interface PricingPlanContent {
  readonly name: string;
  readonly price: number;
  readonly monthlyPrice: number;
  readonly description: string;
  readonly features: readonly string[];
  readonly popular: boolean;
}

export type JourneyMomentIcon = "search" | "journey" | "disruption" | "station";

export interface JourneyMomentContent {
  readonly label: string;
  readonly title: string;
  readonly description: string;
  readonly detail: string;
  readonly icon: JourneyMomentIcon;
  readonly color: string;
}

export interface TransitLine {
  readonly shortName: string;
  readonly color: string;
  readonly textColor: string;
}

export interface JourneyMomentVisuals {
  readonly search: {
    readonly prompt: string;
    readonly result: {
      readonly line: TransitLine;
      readonly destination: string;
      readonly note: string;
    };
  };
  readonly journey: {
    readonly line: TransitLine;
    readonly destination: string;
    readonly nextStop: string;
    readonly minutes: number;
    readonly unit: string;
    readonly progress: number;
  };
  readonly disruption: {
    readonly alert: {
      readonly title: string;
      readonly note: string;
    };
    readonly reroute: {
      readonly line: TransitLine;
      readonly title: string;
      readonly note: string;
    };
  };
  readonly station: {
    readonly name: string;
    readonly distance: string;
    readonly unit: string;
    readonly rows: readonly {
      readonly line: TransitLine;
      readonly destination: string;
      readonly minutes: number;
    }[];
  };
}

export interface FAQContent {
  readonly question: string;
  readonly answer: string;
}
