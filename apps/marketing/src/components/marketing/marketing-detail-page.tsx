import { AnalyticsEvidence } from "@/components/marketing/analytics-evidence";
import { MarketingPageVisual } from "@/components/marketing/marketing-page-visual";
import { ActionLink } from "@/components/ui/action-link";
import { MarketingIcon } from "@/components/ui/marketing-icon";
import { SplitActionLink } from "@/components/ui/split-action-link";
import type {
  LegalSection,
  MarketingCard,
  MarketingPageDefinition,
  MarketingPageSlug,
  MarketingSection,
} from "@/constants/marketing-pages";
import { ArrowDownRight, ArrowRight, Quote } from "lucide-react";
import type { ReactNode } from "react";

function slugify(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

const pageStatements: Record<
  MarketingPageSlug,
  { readonly label: string; readonly title: string; readonly body: string }
> = {
  api: {
    label: "08:17:42 · République",
    title:
      "Une rame ralentit. Votre produit le sait avant que le quai ne se remplisse.",
    body: "Metyro ne livre pas un dump de données. L’API raconte l’état du réseau au présent : ce qui arrive, ce qui change et le niveau de confiance de chaque réponse.",
  },
  integrations: {
    label: "De l’événement à l’action",
    title: "Une perturbation utile n’attend pas dans un nouvel onglet.",
    body: "Elle apparaît sur l’écran du hall, dans le canal de l’équipe ou dans le produit du voyageur — déjà traduite, filtrée et prête à déclencher la bonne décision.",
  },
  analytics: {
    label: "Sous la moyenne",
    title:
      "98,9 % de disponibilité peut encore cacher l’ascenseur dont dépend votre trajet.",
    body: "Nous relions les indicateurs aux moments vécus. Parce qu’un réseau performant sur un tableau peut rester impossible à traverser pour une personne, dans une station, à une heure précise.",
  },
  blog: {
    label: "Carnet de terrain",
    title: "Nous écrivons sur ce que les tableaux de départ ne disent pas.",
    body: "L’attente perçue. Les habitudes qui déplacent une ville. Les détails d’interface qui rendent une mauvaise nouvelle supportable. Et le travail invisible derrière une réponse simple.",
  },
  community: {
    label: "Signal humain",
    title:
      "Le meilleur capteur du réseau tient parfois dans la main d’un voyageur.",
    body: "Une sortie mal indiquée, un ascenseur hors service, une information incompréhensible : le terrain voit toujours quelque chose avant les systèmes. Nous voulons lui donner une voix utile.",
  },
  security: {
    label: "Notre ligne rouge",
    title: "Savoir où vous allez ne nous donne pas le droit de vous suivre.",
    body: "La sécurité de Metyro commence par ce que nous choisissons de ne pas collecter. Puis elle continue dans chaque accès limité, chaque échange chiffré et chaque décision révisable.",
  },
  terms: {
    label: "Lisible par tous",
    title: "Un contrat n’a pas besoin d’être obscur pour être sérieux.",
    body: "Nous expliquons ce que fait le service, ce que vous pouvez en attendre et où s’arrêtent nos responsabilités — avec des phrases que l’on comprend dès la première lecture.",
  },
  help: {
    label: "Deux minutes avant le départ",
    title: "Quand le train arrive, une réponse doit tenir en deux lignes.",
    body: "Le centre d’aide part de votre situation, pas de notre organisation interne. Chaque réponse va droit au geste qui débloque votre trajet.",
  },
};

const closingCopy: Record<
  MarketingPageSlug,
  {
    readonly title: string;
    readonly description: string;
    readonly label: string;
    readonly href: string;
  }
> = {
  api: {
    title: "Mettez le réseau dans votre produit, pas dans votre backlog.",
    description:
      "Commencez par une station, une ligne ou un événement. L’architecture suivra votre ambition.",
    label: "Préparer l’intégration",
    href: "/help#api-et-integrations",
  },
  integrations: {
    title: "Le bon signal. Dans le bon outil. Avant la mauvaise surprise.",
    description:
      "Partez d’un usage réel et construisez le flux qui lui manque.",
    label: "Explorer l’API",
    href: "/api",
  },
  analytics: {
    title: "Ne comptez plus seulement les trains. Comptez les minutes rendues.",
    description:
      "Reliez performance opérationnelle et expérience vécue dans une même lecture.",
    label: "Voir les intégrations",
    href: "/integrations",
  },
  blog: {
    title: "La ville bouge. Nos questions aussi.",
    description:
      "Rejoignez celles et ceux qui veulent comprendre la mobilité au-delà des horaires.",
    label: "Rejoindre la communauté",
    href: "/community",
  },
  community: {
    title: "Ce que vous voyez aujourd’hui peut améliorer le trajet de demain.",
    description:
      "Un détail précis vaut mieux qu’un grand discours. Racontez-nous le vôtre.",
    label: "Trouver le bon contact",
    href: "/help",
  },
  security: {
    title: "La confiance ne se demande pas. Elle se démontre.",
    description:
      "Nos pratiques sont faites pour être comprises, questionnées et améliorées.",
    label: "Lire les conditions",
    href: "/terms",
  },
  terms: {
    title: "Une phrase vous semble floue ? Dites-le-nous.",
    description:
      "Une règle incomprise est une règle mal écrite. Le centre d’aide vous oriente.",
    label: "Ouvrir le centre d’aide",
    href: "/help",
  },
  help: {
    title: "Le problème n’entre dans aucune case ?",
    description:
      "Décrivez le moment exact où Metyro ne vous a pas aidé. C’est là que nous commencerons.",
    label: "Voir la communauté",
    href: "/community",
  },
};

function PageHero({
  page,
}: {
  readonly page: MarketingPageDefinition;
}): ReactNode {
  return (
    <section className="px-6 pt-40 pb-20 sm:pt-48 sm:pb-28">
      <div className="mx-auto grid max-w-6xl items-center gap-14 lg:grid-cols-[1.14fr_0.86fr] lg:gap-24">
        <div>
          <div className="flex items-center gap-3">
            <span
              className="h-2 w-2 rounded-full bg-accent"
              aria-hidden="true"
            />
            <span className="text-xs font-semibold tracking-[0.14em] text-foreground/60 uppercase">
              {page.eyebrow}
            </span>
          </div>
          <h1 className="mt-8 max-w-4xl text-5xl leading-[0.97] font-semibold tracking-[-0.06em] text-balance text-foreground sm:text-6xl lg:text-[5.25rem]">
            {page.title}
          </h1>
          <p className="mt-8 max-w-[58ch] text-lg leading-8 text-muted-foreground sm:text-xl">
            {page.description}
          </p>
          <div className="mt-10 flex flex-wrap items-center gap-3">
            <SplitActionLink {...page.primaryAction} />
            {page.secondaryAction ? (
              <ActionLink {...page.secondaryAction} variant="secondary" />
            ) : null}
          </div>
        </div>

        <MarketingPageVisual page={page} />
      </div>
    </section>
  );
}

function SignalStrip({
  page,
}: {
  readonly page: MarketingPageDefinition;
}): ReactNode {
  if (!page.metrics) return null;

  return (
    <section className="px-6 pb-24 sm:pb-32">
      <div className="mx-auto grid max-w-6xl border-y border-foreground/10 py-7 sm:grid-cols-3 sm:py-0">
        {page.metrics.map((metric, index) => (
          <div
            key={metric.label}
            className={`py-4 sm:px-8 sm:py-7 ${index > 0 ? "border-t border-foreground/10 sm:border-t-0 sm:border-l" : "sm:pl-0"}`}
          >
            <p className="font-mono text-sm font-semibold tracking-tight text-foreground">
              {metric.value}
            </p>
            <p className="mt-1 text-sm text-muted-foreground">{metric.label}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

function StatementSection({
  page,
}: {
  readonly page: MarketingPageDefinition;
}): ReactNode {
  const statement = pageStatements[page.slug];

  return (
    <section className="mx-2.5 overflow-hidden rounded-[2.75rem] bg-[#0b1220] text-white sm:rounded-[4rem]">
      <div className="mx-auto grid min-h-[32rem] max-w-6xl content-between gap-20 px-7 py-12 sm:px-12 sm:py-16 lg:grid-cols-[0.34fr_1fr] lg:gap-16">
        <div className="flex items-start gap-3 font-mono text-xs tracking-[0.12em] text-[#8cb9ff] uppercase">
          <span
            className="mt-1 h-1.5 w-1.5 rounded-full bg-accent"
            aria-hidden="true"
          />
          {statement.label}
        </div>
        <div>
          <h2 className="max-w-4xl text-4xl leading-[1.04] font-semibold tracking-[-0.045em] text-balance sm:text-5xl lg:text-6xl">
            {statement.title}
          </h2>
          <p className="mt-8 max-w-2xl text-lg leading-8 text-white/60">
            {statement.body}
          </p>
        </div>
      </div>
    </section>
  );
}

function FeatureRow({
  card,
  index,
}: {
  readonly card: MarketingCard;
  readonly index: number;
}): ReactNode {
  return (
    <article
      id={slugify(card.title)}
      className="grid gap-6 border-t border-foreground/10 py-10 sm:grid-cols-[4rem_1fr] sm:py-12"
    >
      <div className="flex items-start justify-between sm:block">
        <span className="font-mono text-xs text-muted-foreground">
          0{index + 1}
        </span>
        <span className="flex h-11 w-11 items-center justify-center rounded-2xl bg-accent/10 text-accent sm:mt-6">
          <MarketingIcon name={card.icon} className="h-5 w-5" />
        </span>
      </div>
      <div className="max-w-2xl">
        {card.meta ? (
          <p className="mb-3 text-xs font-semibold tracking-[0.1em] text-accent uppercase">
            {card.meta}
          </p>
        ) : null}
        <h3 className="text-2xl leading-tight font-semibold tracking-[-0.025em] text-balance sm:text-3xl">
          {card.title}
        </h3>
        <p className="mt-4 text-base leading-7 text-muted-foreground sm:text-lg sm:leading-8">
          {card.description}
        </p>
        {card.href ? (
          <a
            href={card.href}
            className="focus-ring mt-6 inline-flex min-h-11 items-center gap-2 rounded-lg text-sm font-semibold text-foreground hover:text-accent"
          >
            Continuer
            <ArrowRight className="h-4 w-4" aria-hidden="true" />
          </a>
        ) : null}
      </div>
    </article>
  );
}

function NarrativeSection({
  section,
  reversed,
}: {
  readonly section: MarketingSection;
  readonly reversed: boolean;
}): ReactNode {
  return (
    <section
      id={slugify(section.eyebrow)}
      className={`scroll-mt-32 px-6 py-24 sm:py-32 ${reversed ? "bg-frame" : ""}`}
    >
      <div className="mx-auto grid max-w-6xl gap-12 lg:grid-cols-[0.72fr_1.28fr] lg:gap-24">
        <div className="lg:pt-11">
          <span className="font-mono text-xs font-semibold tracking-[0.12em] text-accent uppercase">
            {section.eyebrow}
          </span>
          <h2 className="mt-5 text-4xl leading-[1.04] font-semibold tracking-[-0.045em] text-balance sm:text-5xl">
            {section.title}
          </h2>
          <p className="mt-6 max-w-md text-base leading-7 text-muted-foreground sm:text-lg sm:leading-8">
            {section.description}
          </p>
        </div>
        <div>
          {section.cards.map((card, index) => (
            <FeatureRow key={card.title} card={card} index={index} />
          ))}
        </div>
      </div>
    </section>
  );
}

function BlogSection({
  section,
}: {
  readonly section: MarketingSection;
}): ReactNode {
  const [lead, ...articles] = section.cards;
  if (!lead) return null;

  return (
    <section
      id={slugify(section.eyebrow)}
      className="scroll-mt-32 px-6 py-24 sm:py-32"
    >
      <div className="mx-auto max-w-6xl">
        <div className="grid gap-10 lg:grid-cols-[0.7fr_1.3fr] lg:gap-20">
          <div>
            <span className="font-mono text-xs font-semibold tracking-[0.12em] text-accent uppercase">
              {section.eyebrow}
            </span>
            <h2 className="mt-5 text-4xl leading-[1.04] font-semibold tracking-[-0.045em] text-balance sm:text-5xl">
              {section.title}
            </h2>
            <p className="mt-6 text-lg leading-8 text-muted-foreground">
              {section.description}
            </p>
          </div>
          <article className="rounded-[2.5rem] bg-accent p-8 text-white sm:p-12">
            <div className="flex items-center justify-between text-xs font-medium tracking-[0.1em] text-white/60 uppercase">
              <span>{lead.meta}</span>
              <Quote className="h-5 w-5" aria-hidden="true" />
            </div>
            <h3 className="mt-20 max-w-xl text-4xl leading-[1.03] font-semibold tracking-[-0.04em] text-balance sm:text-5xl">
              {lead.title}
            </h3>
            <p className="mt-6 max-w-xl text-lg leading-8 text-white/70">
              {lead.description}
            </p>
          </article>
        </div>
        <div className="mt-20 border-t border-foreground/10">
          {articles.map((article, index) => (
            <article
              key={article.title}
              className="group grid gap-5 border-b border-foreground/10 py-9 sm:grid-cols-[5rem_1fr_auto] sm:items-center"
            >
              <span className="font-mono text-xs text-muted-foreground">
                0{index + 2}
              </span>
              <div>
                <p className="text-xs font-semibold tracking-[0.1em] text-accent uppercase">
                  {article.meta}
                </p>
                <h3 className="mt-2 text-2xl font-semibold tracking-[-0.025em] sm:text-3xl">
                  {article.title}
                </h3>
                <p className="mt-3 max-w-2xl leading-7 text-muted-foreground">
                  {article.description}
                </p>
              </div>
              <ArrowDownRight
                className="hidden h-6 w-6 text-muted-foreground transition-transform duration-150 group-hover:-rotate-45 sm:block"
                aria-hidden="true"
              />
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}

function LegalNavigation({
  sections,
}: {
  readonly sections: readonly LegalSection[];
}): ReactNode {
  return (
    <nav aria-label="Sommaire des conditions" className="lg:sticky lg:top-32">
      <p className="mb-4 font-mono text-xs font-semibold tracking-[0.1em] text-muted-foreground uppercase">
        Sur cette page
      </p>
      <ul className="space-y-1">
        {sections.map((section) => (
          <li key={section.id}>
            <a
              href={`#${section.id}`}
              className="focus-ring block min-h-11 rounded-xl px-3 py-2.5 text-sm text-muted-foreground transition-colors duration-150 hover:bg-frame hover:text-foreground"
            >
              {section.title.replace(/^\d+\.\s*/, "")}
            </a>
          </li>
        ))}
      </ul>
    </nav>
  );
}

function LegalContent({
  page,
}: {
  readonly page: MarketingPageDefinition;
}): ReactNode {
  if (!page.legalSections || !page.legalUpdatedAt) return null;

  return (
    <section className="px-6 py-20 sm:py-28">
      <div className="mx-auto grid max-w-5xl gap-12 lg:grid-cols-[220px_1fr] lg:gap-24">
        <LegalNavigation sections={page.legalSections} />
        <div>
          <p className="mb-14 border-y border-foreground/10 py-5 font-mono text-xs text-muted-foreground">
            DERNIÈRE MISE À JOUR · {page.legalUpdatedAt.toUpperCase()}
          </p>
          {page.legalSections.map((section) => (
            <article
              key={section.id}
              id={section.id}
              className="mb-16 scroll-mt-32"
            >
              <h2 className="text-2xl font-semibold tracking-[-0.025em] sm:text-3xl">
                {section.title}
              </h2>
              <div className="mt-6 space-y-5 text-base leading-8 text-muted-foreground">
                {section.paragraphs.map((paragraph) => (
                  <p key={paragraph}>{paragraph}</p>
                ))}
              </div>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}

function ClosingSection({
  page,
}: {
  readonly page: MarketingPageDefinition;
}): ReactNode {
  const copy = closingCopy[page.slug];

  return (
    <section className="px-6 pt-20 pb-8 sm:pt-28">
      <div className="mx-auto grid max-w-6xl gap-10 rounded-[2.75rem] bg-accent px-8 py-12 text-white sm:px-12 sm:py-16 lg:grid-cols-[1fr_auto] lg:items-end">
        <div className="max-w-3xl">
          <h2 className="text-4xl leading-[1.02] font-semibold tracking-[-0.045em] text-balance sm:text-5xl">
            {copy.title}
          </h2>
          <p className="mt-5 max-w-2xl text-lg leading-8 text-white/70">
            {copy.description}
          </p>
        </div>
        <SplitActionLink label={copy.label} href={copy.href} tone="dark" />
      </div>
    </section>
  );
}

export function MarketingDetailPage({
  page,
}: {
  readonly page: MarketingPageDefinition;
}): ReactNode {
  return (
    <main id="main-content" className="flex-1">
      <PageHero page={page} />
      <SignalStrip page={page} />
      <StatementSection page={page} />
      {page.slug === "analytics" ? <AnalyticsEvidence /> : null}
      {page.kind === "legal" ? (
        <LegalContent page={page} />
      ) : page.kind === "editorial" ? (
        page.sections?.map((section) => (
          <BlogSection key={section.title} section={section} />
        ))
      ) : (
        page.sections?.map((section, index) => (
          <NarrativeSection
            key={section.title}
            section={section}
            reversed={index % 2 === 1}
          />
        ))
      )}
      <ClosingSection page={page} />
    </main>
  );
}
