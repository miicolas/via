import { SectionHeading } from "@/components/ui/section-heading";
import { TransitText } from "@/components/ui/transit-text";
import type { CommunityContent } from "@/constants/community-page";
import { Braces, Check, CircleDashed, MessageCircle } from "lucide-react";
import type { ReactNode } from "react";
import { ParticipationTile } from "./participation-tile";

type Participation = CommunityContent["participation"];

function ReportVisual({
  visual,
}: {
  readonly visual: Participation["report"]["visual"];
}): ReactNode {
  return (
    <div className="mx-auto w-full max-w-sm rounded-2xl border border-border bg-background p-5 shadow-2xl/10">
      <div className="flex items-center justify-between text-muted-foreground">
        <span className="font-mono text-[10px] tracking-wider uppercase">
          <TransitText>{visual.meta}</TransitText>
        </span>
        <MessageCircle className="h-4 w-4" aria-hidden="true" />
      </div>
      <p className="mt-4 text-sm leading-6 font-medium text-foreground">
        <TransitText>{visual.quote}</TransitText>
      </p>
      <div className="mt-4 inline-flex items-center gap-1.5 rounded-full bg-accent/10 py-1 pr-3 pl-2 text-xs font-medium text-accent">
        <Check className="h-3.5 w-3.5" aria-hidden="true" />
        {visual.status}
      </div>
    </div>
  );
}

function FieldCheckVisual({
  visual,
}: {
  readonly visual: Participation["fieldCheck"]["visual"];
}): ReactNode {
  return (
    <div className="mx-auto w-full max-w-xs space-y-2.5">
      {visual.rows.map((row) => (
        <div
          key={row.label}
          className="flex items-center justify-between gap-3 rounded-2xl border border-border bg-background px-4 py-3"
        >
          <span className="text-sm font-medium text-foreground">
            {row.label}
          </span>
          <span
            className={`inline-flex items-center gap-1.5 text-xs font-medium ${row.done ? "text-accent" : "text-muted-foreground"}`}
          >
            {row.done ? (
              <Check className="h-3.5 w-3.5" aria-hidden="true" />
            ) : (
              <CircleDashed className="h-3.5 w-3.5" aria-hidden="true" />
            )}
            {row.status}
          </span>
        </div>
      ))}
    </div>
  );
}

function ApiVisual(): ReactNode {
  return (
    <div className="mx-auto w-full max-w-xs rounded-2xl bg-[#0b1220] p-5 font-mono text-[11px] leading-6 text-white shadow-2xl/20">
      <div className="mb-3 flex items-center justify-between text-white/45">
        <span>GET /v1/elevators</span>
        <Braces className="h-4 w-4" aria-hidden="true" />
      </div>
      <pre className="overflow-hidden">
        <code>
          <span className="text-[#8cb9ff]">{"{"}</span>
          {"\n"}
          {"  "}
          <span className="text-[#a6e3a1]">&quot;station&quot;</span>:{" "}
          <span className="text-[#f9c784]">&quot;Jaurès&quot;</span>,{"\n"}
          {"  "}
          <span className="text-[#a6e3a1]">&quot;status&quot;</span>:{" "}
          <span className="text-[#f9c784]">&quot;down&quot;</span>,{"\n"}
          {"  "}
          <span className="text-[#a6e3a1]">&quot;since&quot;</span>:{" "}
          <span className="text-[#f9c784]">&quot;07:12&quot;</span>
          {"\n"}
          <span className="text-[#8cb9ff]">{"}"}</span>
        </code>
      </pre>
    </div>
  );
}

function ExpansionVisual({
  visual,
}: {
  readonly visual: Participation["expansion"]["visual"];
}): ReactNode {
  return (
    <div className="mx-auto w-full max-w-sm space-y-4">
      {visual.rows.map((row, index) => (
        <div key={row.city}>
          <div className="mb-1.5 flex items-baseline justify-between text-sm text-white">
            <span className="font-medium">{row.city}</span>
            {index === 0 ? (
              <span className="font-mono text-[10px] tracking-wider text-white/55 uppercase">
                {visual.unit}
              </span>
            ) : null}
          </div>
          <div
            className="h-1.5 overflow-hidden rounded-full bg-white/15"
            aria-hidden="true"
          >
            <div
              className="h-full rounded-full bg-white/90"
              style={{ width: `${row.strength}%` }}
            />
          </div>
        </div>
      ))}
    </div>
  );
}

export function CommunityParticipationSection({
  content,
}: {
  readonly content: Participation;
}): ReactNode {
  return (
    <section id="participer" className="w-full scroll-mt-24 px-6 pb-28 sm:pb-32">
      <div className="mx-auto max-w-5xl">
        <SectionHeading
          eyebrow={content.eyebrow}
          title={content.title}
          description={content.description}
        />
        <div className="grid grid-cols-1 gap-4 md:grid-cols-5">
          <ParticipationTile
            title={content.report.title}
            hint={content.report.hint}
            index={0}
            action={content.report.action}
            className="md:col-span-3"
          >
            <ReportVisual visual={content.report.visual} />
          </ParticipationTile>
          <ParticipationTile
            title={content.fieldCheck.title}
            hint={content.fieldCheck.hint}
            index={1}
            className="md:col-span-2"
          >
            <FieldCheckVisual visual={content.fieldCheck.visual} />
          </ParticipationTile>
          <ParticipationTile
            title={content.api.title}
            hint={content.api.hint}
            index={2}
            action={content.api.action}
            className="md:col-span-2"
          >
            <ApiVisual />
          </ParticipationTile>
          <ParticipationTile
            title={content.expansion.title}
            hint={content.expansion.hint}
            index={3}
            variant="primary"
            action={content.expansion.action}
            className="md:col-span-3"
          >
            <ExpansionVisual visual={content.expansion.visual} />
          </ParticipationTile>
        </div>
      </div>
    </section>
  );
}
