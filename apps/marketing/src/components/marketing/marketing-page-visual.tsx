import { gareDuNordHourlyProfile } from "@/constants/analytics-data";
import type { MarketingPageDefinition } from "@/constants/marketing-pages";
import {
  Activity,
  BarChart3,
  BookOpen,
  Braces,
  Check,
  ChevronRight,
  CircleUserRound,
  FileText,
  Link2,
  LockKeyhole,
  MessageCircle,
  Search,
  ShieldCheck,
  Sparkles,
} from "lucide-react";
import type { ReactNode } from "react";

const compactHourlyProfile = gareDuNordHourlyProfile.slice(5, 21);

function ApiVisual(): ReactNode {
  return (
    <div className="rounded-3xl bg-[#0b1220] p-5 text-sm text-white shadow-2xl/20 sm:p-7">
      <div className="mb-6 flex items-center justify-between text-white/45">
        <span className="font-mono text-xs">GET /v1/departures</span>
        <Braces className="h-4 w-4" aria-hidden="true" />
      </div>
      <pre className="overflow-hidden font-mono text-[11px] leading-6 sm:text-xs">
        <code>
          <span className="text-[#8cb9ff]">{"{"}</span>
          {"\n"}
          {"  "}
          <span className="text-[#a6e3a1]">&quot;station&quot;</span>:{" "}
          <span className="text-[#f9c784]">&quot;République&quot;</span>,{"\n"}
          {"  "}
          <span className="text-[#a6e3a1]">&quot;line&quot;</span>:{" "}
          <span className="text-[#f9c784]">&quot;11&quot;</span>,{"\n"}
          {"  "}
          <span className="text-[#a6e3a1]">&quot;departures&quot;</span>: [
          <span className="text-[#c9b8ff]">2, 6, 11</span>],{"\n"}
          {"  "}
          <span className="text-[#a6e3a1]">&quot;live&quot;</span>:{" "}
          <span className="text-[#8cb9ff]">true</span>
          {"\n"}
          <span className="text-[#8cb9ff]">{"}"}</span>
        </code>
      </pre>
    </div>
  );
}

function IntegrationsVisual(): ReactNode {
  const items = [
    { label: "Metyro", icon: Sparkles, featured: true },
    { label: "Alertes", icon: MessageCircle, featured: false },
    { label: "Données", icon: Activity, featured: false },
    { label: "Produits", icon: Link2, featured: false },
  ];

  return (
    <div className="grid grid-cols-2 gap-3 sm:gap-4">
      {items.map(({ label, icon: Icon, featured }) => (
        <div
          key={label}
          className={`flex aspect-[1.3] flex-col justify-between rounded-3xl p-5 ${featured ? "bg-accent text-white" : "bg-frame text-foreground"}`}
        >
          <Icon className="h-6 w-6" aria-hidden="true" />
          <span className="text-sm font-semibold">{label}</span>
        </div>
      ))}
    </div>
  );
}

function AnalyticsVisual(): ReactNode {
  return (
    <div className="rounded-3xl bg-frame p-5 shadow-2xl/10 sm:p-7">
      <div className="flex items-start justify-between">
        <div>
          <span className="text-xs text-muted-foreground">
            Gare du Nord · 8 h–9 h
          </span>
          <p className="mt-1 text-3xl font-semibold tracking-tight">12,84 %</p>
        </div>
        <div className="rounded-full bg-accent/10 px-3 py-1 text-xs font-medium text-accent">
          T4 2024
        </div>
      </div>
      <div className="mt-10 flex h-36 items-end gap-2 sm:gap-3">
        {compactHourlyProfile.map((point) => (
          <div
            key={point.hour}
            className={`flex-1 rounded-t-sm ${point.hour === "08h" ? "bg-accent" : "bg-accent/20"}`}
            style={{ height: `${Math.max((point.share / 12.84) * 100, 2)}%` }}
          />
        ))}
      </div>
      <div className="mt-3 flex justify-between text-[10px] text-muted-foreground">
        <span>05 h</span>
        <span>12 h</span>
        <span>20 h</span>
      </div>
    </div>
  );
}

function EditorialVisual(): ReactNode {
  return (
    <div className="relative min-h-80 overflow-hidden rounded-3xl bg-[#102a45] p-7 text-white sm:p-9">
      <div className="absolute -top-10 -right-6 h-52 w-52 rounded-full bg-accent blur-3xl" />
      <BookOpen className="relative h-7 w-7" aria-hidden="true" />
      <div className="relative mt-24 max-w-sm">
        <span className="text-xs font-medium text-white/60">
          LE JOURNAL · Nº 01
        </span>
        <p className="mt-3 text-3xl font-semibold tracking-tight">
          La ville se lit aussi entre deux stations.
        </p>
      </div>
    </div>
  );
}

function CommunityVisual(): ReactNode {
  const positions = [
    "top-5 left-8",
    "top-12 right-9",
    "top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2",
    "bottom-8 left-14",
    "right-16 bottom-5",
  ];
  return (
    <div className="relative min-h-80 overflow-hidden rounded-3xl bg-[#dceaff] dark:bg-[#102a45]">
      <div className="absolute inset-12 rounded-full border border-accent/20" />
      <div className="absolute inset-24 rounded-full border border-accent/30" />
      {positions.map((position, index) => (
        <div
          key={position}
          className={`absolute ${position} flex h-14 w-14 items-center justify-center rounded-full border-4 border-white bg-accent text-white shadow-xl dark:border-[#102a45] ${index === 2 ? "h-20 w-20" : ""}`}
        >
          <CircleUserRound
            className={index === 2 ? "h-9 w-9" : "h-6 w-6"}
            aria-hidden="true"
          />
        </div>
      ))}
    </div>
  );
}

function SecurityVisual(): ReactNode {
  return (
    <div className="flex min-h-80 items-center justify-center rounded-3xl bg-[#0b1220] p-8 text-white">
      <div className="relative flex h-44 w-44 items-center justify-center rounded-full border border-white/10">
        <div className="absolute inset-5 rounded-full border border-white/15" />
        <div className="relative flex h-24 w-24 items-center justify-center rounded-3xl bg-accent shadow-[0_0_80px_rgba(24,114,247,0.65)]">
          <ShieldCheck className="h-11 w-11" aria-hidden="true" />
        </div>
        <Check
          className="absolute top-2 right-3 h-5 w-5 text-[#74dc9d]"
          aria-hidden="true"
        />
        <LockKeyhole
          className="absolute bottom-2 left-3 h-5 w-5 text-[#8cb9ff]"
          aria-hidden="true"
        />
      </div>
    </div>
  );
}

function TermsVisual(): ReactNode {
  return (
    <div className="min-h-80 rounded-3xl bg-frame p-5 shadow-2xl/10 sm:p-8">
      <div className="mx-auto max-w-sm rounded-2xl border border-border bg-background p-6">
        <div className="flex items-center justify-between">
          <FileText className="h-6 w-6 text-accent" aria-hidden="true" />
          <span className="text-[10px] font-medium tracking-wider text-muted-foreground uppercase">
            Version 2026
          </span>
        </div>
        <div className="mt-8 space-y-4">
          {[
            "Conditions d’utilisation",
            "Le service Metyro",
            "Utilisation acceptable",
            "Vos droits",
          ].map((label, index) => (
            <div
              key={label}
              className="flex items-center gap-3 border-b border-border pb-3 text-sm"
            >
              <span className="text-xs text-muted-foreground">
                0{index + 1}
              </span>
              <span className="font-medium">{label}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function HelpVisual(): ReactNode {
  return (
    <div className="min-h-80 rounded-3xl bg-frame p-5 shadow-2xl/10 sm:p-8">
      <div className="rounded-2xl border border-border bg-background p-4">
        <div className="flex items-center gap-3 text-muted-foreground">
          <Search className="h-5 w-5" aria-hidden="true" />
          <span className="text-sm">Comment pouvons-nous vous aider ?</span>
        </div>
      </div>
      <div className="mt-5 space-y-3">
        {[
          "Comprendre le temps réel",
          "Configurer mes alertes",
          "Utiliser mes favoris",
        ].map((label) => (
          <div
            key={label}
            className="flex items-center justify-between rounded-2xl bg-muted p-4"
          >
            <span className="text-sm font-medium">{label}</span>
            <ChevronRight
              className="h-4 w-4 text-muted-foreground"
              aria-hidden="true"
            />
          </div>
        ))}
      </div>
    </div>
  );
}

export function MarketingPageVisual({
  page,
}: {
  readonly page: MarketingPageDefinition;
}): ReactNode {
  let visual: ReactNode;

  switch (page.signal) {
    case "api":
      visual = <ApiVisual />;
      break;
    case "integrations":
      visual = <IntegrationsVisual />;
      break;
    case "analytics":
      visual = <AnalyticsVisual />;
      break;
    case "blog":
      visual = <EditorialVisual />;
      break;
    case "community":
      visual = <CommunityVisual />;
      break;
    case "security":
      visual = <SecurityVisual />;
      break;
    case "terms":
      visual = <TermsVisual />;
      break;
    case "help":
      visual = <HelpVisual />;
      break;
    default:
      visual = (
        <BarChart3 className="h-12 w-12 text-accent" aria-hidden="true" />
      );
  }

  return (
    <div
      role="img"
      aria-label={`Illustration de la page ${page.eyebrow}`}
      className="pointer-events-none select-none"
    >
      {visual}
    </div>
  );
}
