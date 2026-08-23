"use client";

import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@/components/ui/chart";
import {
  analyticsSources,
  elevatorAvailability,
  gareDuNordHourlyProfile,
} from "@/constants/analytics-data";
import { ArrowUpRight } from "lucide-react";
import type { ReactNode } from "react";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  XAxis,
  YAxis,
} from "recharts";

const hourlyConfig = {
  share: {
    label: "Part des validations",
    color: "var(--accent)",
  },
} satisfies ChartConfig;

const availabilityConfig = {
  result: {
    label: "Résultat observé",
    color: "var(--accent)",
  },
  target: {
    label: "Objectif contractuel",
    color: "#9fb0c7",
  },
} satisfies ChartConfig;

function SourceNote({
  source,
}: {
  readonly source: (typeof analyticsSources)[keyof typeof analyticsSources];
}): ReactNode {
  return (
    <div className="mt-7 border-t border-foreground/10 pt-5 text-xs leading-5 text-muted-foreground">
      <p>{source.note}</p>
      <a
        href={source.href}
        target="_blank"
        rel="noreferrer"
        className="focus-ring mt-3 inline-flex min-h-11 items-center gap-1.5 rounded-lg font-semibold text-foreground hover:text-accent"
      >
        Source · Île-de-France Mobilités
        <ArrowUpRight className="h-3.5 w-3.5" aria-hidden="true" />
        <span className="sr-only"> — {source.label}</span>
      </a>
    </div>
  );
}

function HourlyProfileChart(): ReactNode {
  return (
    <article className="rounded-[2.5rem] bg-frame p-6 shadow-[0_0_0_1px_rgba(10,10,10,0.06)] sm:p-9">
      <div className="flex flex-col justify-between gap-6 sm:flex-row sm:items-start">
        <div>
          <p className="font-mono text-xs tracking-[0.1em] text-accent uppercase">
            Gare du Nord · T4 2024
          </p>
          <h3 className="mt-3 max-w-xl text-3xl leading-tight font-semibold tracking-[-0.035em] text-balance sm:text-4xl">
            La pointe du matin ne monte pas. Elle surgit.
          </h3>
        </div>
        <div className="sm:text-right">
          <p className="font-mono text-3xl font-semibold tracking-tight tabular-nums">
            12,84 %
          </p>
          <p className="mt-1 text-sm text-muted-foreground">entre 8 h et 9 h</p>
        </div>
      </div>

      <ChartContainer
        config={hourlyConfig}
        className="mt-10 h-72 w-full sm:h-80"
        aria-label="Répartition horaire des validations à Gare du Nord un jour ouvré hors vacances scolaires au quatrième trimestre 2024"
      >
        <AreaChart
          accessibilityLayer
          data={gareDuNordHourlyProfile}
          margin={{ left: -12, right: 8, top: 8 }}
        >
          <defs>
            <linearGradient id="hourly-fill" x1="0" y1="0" x2="0" y2="1">
              <stop
                offset="5%"
                stopColor="var(--color-share)"
                stopOpacity={0.34}
              />
              <stop
                offset="95%"
                stopColor="var(--color-share)"
                stopOpacity={0.02}
              />
            </linearGradient>
          </defs>
          <CartesianGrid vertical={false} />
          <XAxis
            dataKey="hour"
            tickLine={false}
            axisLine={false}
            tickMargin={12}
            interval={2}
          />
          <YAxis
            tickLine={false}
            axisLine={false}
            tickMargin={8}
            width={40}
            tickFormatter={(value: number) => `${value} %`}
          />
          <ChartTooltip
            cursor={false}
            content={
              <ChartTooltipContent
                indicator="line"
                formatter={(value) => (
                  <div className="flex min-w-40 items-center justify-between gap-5">
                    <span className="text-muted-foreground">
                      Part des validations
                    </span>
                    <span className="font-mono font-semibold tabular-nums">
                      {Number(value).toLocaleString("fr-FR")} %
                    </span>
                  </div>
                )}
              />
            }
          />
          <Area
            type="monotone"
            dataKey="share"
            stroke="var(--color-share)"
            strokeWidth={3}
            fill="url(#hourly-fill)"
            activeDot={{ r: 5, strokeWidth: 0 }}
          />
        </AreaChart>
      </ChartContainer>

      <div className="grid gap-4 border-t border-foreground/10 pt-6 sm:grid-cols-3">
        <div>
          <p className="font-mono text-lg font-semibold tabular-nums">
            30,19 %
          </p>
          <p className="mt-1 text-sm leading-5 text-muted-foreground">
            des validations ont lieu entre 7 h et 10 h.
          </p>
        </div>
        <div>
          <p className="font-mono text-lg font-semibold tabular-nums">
            19,70 %
          </p>
          <p className="mt-1 text-sm leading-5 text-muted-foreground">
            se concentrent entre 17 h et 20 h.
          </p>
        </div>
        <div>
          <p className="font-mono text-lg font-semibold">Deux pointes</p>
          <p className="mt-1 text-sm leading-5 text-muted-foreground">
            mais deux formes et deux expériences différentes.
          </p>
        </div>
      </div>

      <SourceNote source={analyticsSources.hourlyProfile} />
    </article>
  );
}

function AvailabilityChart(): ReactNode {
  return (
    <article className="rounded-[2.5rem] bg-[#0b1220] p-6 text-white shadow-2xl/10 sm:p-9">
      <div className="grid gap-6 lg:grid-cols-[1fr_auto] lg:items-start">
        <div>
          <p className="font-mono text-xs tracking-[0.1em] text-[#8cb9ff] uppercase">
            Accessibilité · T4 2024
          </p>
          <h3 className="mt-3 max-w-2xl text-3xl leading-tight font-semibold tracking-[-0.035em] text-balance sm:text-4xl">
            Un dixième de point n’est pas petit quand l’ascenseur est le seul
            chemin.
          </h3>
        </div>
        <div className="flex gap-5 text-xs text-white/60">
          <span className="flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-sm bg-accent" /> Résultat
          </span>
          <span className="flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-sm bg-[#9fb0c7]" /> Objectif
          </span>
        </div>
      </div>

      <ChartContainer
        config={availabilityConfig}
        className="mt-10 h-80 w-full sm:h-96 [&_.recharts-cartesian-axis-tick_text]:fill-white/55 [&_.recharts-cartesian-grid_line]:stroke-white/10"
        aria-label="Disponibilité des ascenseurs RATP comparée aux objectifs contractuels au quatrième trimestre 2024"
      >
        <BarChart
          accessibilityLayer
          data={elevatorAvailability}
          margin={{ left: -4, right: 8, top: 8 }}
        >
          <CartesianGrid vertical={false} />
          <XAxis
            dataKey="network"
            tickLine={false}
            axisLine={false}
            tickMargin={12}
            tickFormatter={(value: string) => value.replace("Métro ", "M. ")}
          />
          <YAxis
            domain={[95, 100]}
            tickLine={false}
            axisLine={false}
            tickMargin={8}
            width={42}
            tickFormatter={(value: number) => `${value} %`}
          />
          <ChartTooltip
            cursor={{ fill: "rgba(255,255,255,0.04)" }}
            content={<ChartTooltipContent />}
          />
          <Bar
            dataKey="result"
            fill="var(--color-result)"
            radius={[6, 6, 0, 0]}
          />
          <Bar
            dataKey="target"
            fill="var(--color-target)"
            radius={[6, 6, 0, 0]}
          />
        </BarChart>
      </ChartContainer>

      <div className="grid gap-4 border-t border-white/10 pt-6 sm:grid-cols-2">
        <p className="text-sm leading-6 text-white/60">
          Les métros classiques, modernisés et automatiques dépassent leur
          objectif publié au T4 2024.
        </p>
        <p className="text-sm leading-6 text-white/60">
          Les RER A et B restent respectivement à 0,6 point sous leur cible. Axe
          vertical resserré à 95–100 % pour rendre l’écart visible.
        </p>
      </div>

      <SourceNote source={analyticsSources.accessibility} />
    </article>
  );
}

export function AnalyticsEvidence(): ReactNode {
  return (
    <section className="px-6 py-24 sm:py-32">
      <div className="mx-auto max-w-6xl">
        <div className="mb-14 grid gap-8 lg:grid-cols-[0.72fr_1.28fr] lg:items-end">
          <div>
            <p className="font-mono text-xs font-semibold tracking-[0.12em] text-accent uppercase">
              Données réelles, lecture humaine
            </p>
            <h2 className="mt-5 text-4xl leading-[1.04] font-semibold tracking-[-0.045em] text-balance sm:text-5xl">
              Les chiffres ne décorent pas la page. Ils changent la question.
            </h2>
          </div>
          <p className="max-w-2xl text-lg leading-8 text-muted-foreground lg:justify-self-end">
            Ces visualisations utilisent les jeux de données officiels
            d’Île-de-France Mobilités. Chaque valeur garde son périmètre, sa
            période et sa source — pour éviter qu’un beau graphique raconte une
            fausse histoire.
          </p>
        </div>
        <div className="space-y-6">
          <HourlyProfileChart />
          <AvailabilityChart />
        </div>
      </div>
    </section>
  );
}
