"use client";

import {
  ArrowDown,
  ArrowRight,
  Check,
  Clock3,
  Copy,
  ExternalLink,
  Flag,
  MapPin,
  RefreshCw,
  Share2,
  TriangleAlert,
  Footprints,
} from "lucide-react";
import Link from "next/link";
import type { ReactNode } from "react";
import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useQueryStates } from "nuqs";

import type { JourneySection, JourneyShareResponse } from "@via/contract";
import { AppStoreBadgeLink } from "@/components/ui/app-store-badge-link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Map,
  MapControls,
  MapMarker,
  MapRoute,
  MarkerContent,
} from "@/components/ui/map";
import { cn } from "@/lib/utils";
import { LineBadge } from "@/components/ui/line-badge";
import {
  formatDuration,
  journeyEndpoints,
  journeyShareQueryOptions,
  type JourneyShareErrorCode,
} from "@/lib/journey-share";
import { journeySearchParams } from "./search-params";

type Coordinate = { readonly latitude: number; readonly longitude: number };
type MapCoordinate = [number, number];

const sectionTypeLabels: Record<JourneySection["type"], string> = {
  walk: "À pied",
  bike: "À vélo",
  wait: "Attente",
  transfer: "Correspondance",
  transit: "Transport",
};

const sectionTypeColors: Record<JourneySection["type"], string> = {
  walk: "#64748b",
  bike: "#059669",
  wait: "#a855f7",
  transfer: "#f59e0b",
  transit: "#1872f7",
};

export function JourneySharePageClient({
  token,
}: {
  readonly token: string;
}): ReactNode {
  const query = useQuery(journeyShareQueryOptions(token));
  const [{ leg, view }, setSearchParams] = useQueryStates(journeySearchParams);
  const [copied, setCopied] = useState(false);

  if (query.isPending && query.data === undefined) return <LoadingState />;
  if (query.isError) {
    return (
      <JourneyShareErrorState
        code="unavailable"
        onRetry={() => void query.refetch()}
      />
    );
  }

  const result = query.data;
  if (!result || result.kind === "error") {
    return (
      <JourneyShareErrorState
        code={result?.kind === "error" ? result.code : "unavailable"}
        onRetry={() => void query.refetch()}
      />
    );
  }

  const share = result.share;
  const journey = share.snapshot.journey;
  const sections = journey.sections;
  const selectedLeg = clamp(leg, 0, Math.max(sections.length - 1, 0));
  const locale = safeLocale(share.snapshot.locale);
  const timeZone = safeTimeZone(share.snapshot.timeZone);
  const { origin, destination } = journeyEndpoints(share);

  const copyLink = async () => {
    if (!navigator.clipboard) return;
    await navigator.clipboard.writeText(window.location.href);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 2_000);
  };

  const selectLeg = (index: number) => {
    void setSearchParams({ leg: index, view: "details" });
  };

  return (
    <main className="min-h-svh bg-background text-foreground">
      <div className="mx-auto flex min-h-svh max-w-[1440px] flex-col px-4 py-4 sm:px-6 sm:py-6">
        <header className="flex items-center justify-between gap-4 pb-4 sm:pb-6">
          <Link
            href="/"
            className="focus-ring inline-flex items-center gap-2 text-sm font-semibold"
          >
            <span className="grid size-8 place-items-center rounded-xl bg-foreground text-background">
              M
            </span>
            Metyro
          </Link>
          <div className="flex items-center gap-2">
            <Badge variant="secondary" className="hidden sm:inline-flex">
              Trajet partagé
            </Badge>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={copyLink}
              aria-label={copied ? "Lien copié" : "Copier le lien"}
            >
              {copied ? <Check /> : <Copy />}
              <span className="hidden sm:inline">
                {copied ? "Copié" : "Copier le lien"}
              </span>
            </Button>
          </div>
        </header>

        <div className="grid flex-1 gap-4 lg:grid-cols-[minmax(0,1.15fr)_minmax(360px,0.85fr)]">
          <section
            aria-label="Carte du trajet"
            className={cn(
              "relative min-h-[52svh] overflow-hidden rounded-[1.75rem] border bg-muted shadow-sm lg:min-h-[calc(100svh-8rem)]",
              view === "details" && "hidden lg:block",
            )}
          >
            <JourneyShareMap journey={journey} selectedLeg={selectedLeg} />
            <div className="absolute top-4 left-4 max-w-[calc(100%-2rem)] rounded-2xl border bg-background/90 px-3 py-2 text-xs shadow-lg backdrop-blur">
              <p className="font-semibold">{origin.name}</p>
              <div className="my-1 flex items-center gap-1 text-muted-foreground">
                <ArrowDown className="size-3" />
                <span>{formatDuration(journey.durationSeconds)}</span>
              </div>
              <p className="font-semibold">{destination.name}</p>
            </div>
          </section>

          <section
            aria-labelledby="journey-title"
            className={cn(
              "flex min-w-0 flex-col rounded-[1.75rem] border bg-background p-5 shadow-sm sm:p-7 lg:max-h-[calc(100svh-8rem)] lg:overflow-y-auto",
              view === "map" && "hidden lg:flex",
            )}
          >
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-sm font-medium text-muted-foreground">
                  Itinéraire Metyro
                </p>
                <h1
                  id="journey-title"
                  className="mt-2 text-3xl leading-tight font-semibold tracking-tight text-balance sm:text-4xl"
                >
                  {origin.name} <span className="text-muted-foreground">→</span>{" "}
                  {destination.name}
                </h1>
              </div>
              <Badge
                variant={
                  journey.status === "disrupted" ? "destructive" : "secondary"
                }
              >
                {journeyStatusLabel(journey.status)}
              </Badge>
            </div>

            <p className="mt-4 flex items-center gap-2 text-sm text-muted-foreground">
              <Clock3 className="size-4" />
              {formatDateRange(
                journey.departureAt,
                journey.arrivalAt,
                locale,
                timeZone,
              )}
            </p>

            <div className="mt-6 grid grid-cols-3 divide-x rounded-2xl bg-muted/60 py-4">
              <Stat
                label="Durée"
                value={formatDuration(journey.durationSeconds)}
              />
              <Stat
                label="Correspondances"
                value={`${journey.transferCount}`}
              />
              <Stat
                label="À pied"
                value={formatDuration(journey.walkingDurationSeconds)}
              />
            </div>

            {journey.warnings.length > 0 && (
              <div className="mt-5 rounded-2xl border border-amber-500/30 bg-amber-500/10 p-4 text-sm">
                <p className="flex items-center gap-2 font-semibold text-amber-800 dark:text-amber-200">
                  <TriangleAlert className="size-4" />À savoir
                </p>
                <ul className="mt-2 space-y-1 text-muted-foreground">
                  {journey.warnings.map((warning) => (
                    <li key={warning}>{warning}</li>
                  ))}
                </ul>
              </div>
            )}

            <div className="mt-7 flex items-center justify-between gap-3">
              <h2 className="text-lg font-semibold">Étapes du trajet</h2>
              <div
                className="flex rounded-xl bg-muted p-1 lg:hidden"
                aria-label="Affichage"
              >
                <Button
                  type="button"
                  size="sm"
                  variant={view === "map" ? "default" : "ghost"}
                  aria-pressed={view === "map"}
                  onClick={() => void setSearchParams({ view: "map" })}
                >
                  <MapPin />
                  <span className="sr-only">Carte</span>
                </Button>
                <Button
                  type="button"
                  size="sm"
                  variant={view === "details" ? "default" : "ghost"}
                  aria-pressed={view === "details"}
                  onClick={() => void setSearchParams({ view: "details" })}
                >
                  <ArrowRight />
                  <span className="sr-only">Détails</span>
                </Button>
              </div>
            </div>

            <ol className="mt-4 space-y-2">
              {sections.map((section, index) => (
                <JourneySectionRow
                  key={`${section.id ?? "section"}-${index}`}
                  section={section}
                  index={index}
                  selected={selectedLeg === index}
                  locale={locale}
                  timeZone={timeZone}
                  onSelect={() => selectLeg(index)}
                />
              ))}
            </ol>

            <div className="mt-7 border-t pt-6">
              <p className="text-sm font-semibold">
                Envie de le garder sous la main ?
              </p>
              <p className="mt-1 text-sm leading-6 text-muted-foreground">
                Ouvrez ce trajet dans Metyro pour retrouver une expérience
                complète et préparer vos prochains déplacements.
              </p>
              <div className="mt-4 flex flex-wrap items-center gap-3">
                <a
                  href={`via://trip/${token}`}
                  className="focus-ring inline-flex min-h-11 items-center gap-2 rounded-xl bg-foreground px-4 text-sm font-semibold text-background transition-opacity hover:opacity-90"
                >
                  <ExternalLink className="size-4" />
                  Ouvrir dans l’app
                </a>
                <AppStoreBadgeLink
                  label="Télécharger Metyro sur l’App Store"
                  href="/#download"
                />
              </div>
            </div>

            <p className="mt-6 text-xs text-muted-foreground">
              Trajet calculé le{" "}
              {formatDate(share.snapshot.generatedAt, locale, timeZone)} · lien
              valable jusqu’au {formatDate(share.expiresAt, locale, timeZone)}
            </p>
          </section>
        </div>
      </div>
    </main>
  );
}

function JourneyShareMap({
  journey,
  selectedLeg,
}: {
  readonly journey: JourneyShareResponse["snapshot"]["journey"];
  readonly selectedLeg: number;
}): ReactNode {
  /**
   * La géométrie est projetée une fois, pas à chaque rendu : `MapRoute` a
   * `coordinates` dans ses dépendances et appelle `setData`, donc un tableau
   * neuf réenvoie toute la polyligne à MapLibre. Sélectionner une étape ne doit
   * coûter que deux propriétés de peinture.
   */
  const routes = useMemo(
    () =>
      journey.sections.flatMap((section, index) => {
        const coordinates = section.geometry.map(toMapCoordinate);
        if (coordinates.length < 2) return [];
        return [
          {
            key: `route-${section.id ?? index}`,
            id: `journey-share-${index}`,
            index,
            coordinates,
            color: section.route
              ? cssColor(section.route.color, sectionTypeColors[section.type])
              : sectionTypeColors[section.type],
          },
        ];
      }),
    [journey.sections],
  );
  const map = useMemo(
    () => mapConfiguration(routes.flatMap((route) => route.coordinates)),
    [routes],
  );
  const endpoints = {
    origin: journey.sections[0]?.from,
    destination: journey.sections[journey.sections.length - 1]?.to,
  };

  return (
    <Map
      center={map.center}
      zoom={map.zoom}
      minZoom={map.minZoom}
      maxZoom={map.maxZoom}
    >
      <MapControls
        position="bottom-right"
        showZoom
        showCompass
        showFullscreen
      />
      {routes.map((route) => (
        <MapRoute
          key={route.key}
          id={route.id}
          coordinates={route.coordinates}
          color={route.color}
          width={route.index === selectedLeg ? 7 : 4}
          opacity={route.index === selectedLeg ? 1 : 0.62}
          interactive={false}
        />
      ))}
      {endpoints.origin && (
        <MapMarker
          longitude={endpoints.origin.coordinate.longitude}
          latitude={endpoints.origin.coordinate.latitude}
          anchor="bottom"
        >
          <MarkerContent>
            <div className="grid size-9 place-items-center rounded-full border-2 border-white bg-emerald-500 text-white shadow-lg">
              <MapPin className="size-4" />
            </div>
          </MarkerContent>
        </MapMarker>
      )}
      {endpoints.destination && (
        <MapMarker
          longitude={endpoints.destination.coordinate.longitude}
          latitude={endpoints.destination.coordinate.latitude}
          anchor="bottom"
        >
          <MarkerContent>
            <div className="grid size-9 place-items-center rounded-full border-2 border-white bg-rose-500 text-white shadow-lg">
              <Flag className="size-4" />
            </div>
          </MarkerContent>
        </MapMarker>
      )}
    </Map>
  );
}

function JourneySectionRow({
  section,
  index,
  selected,
  locale,
  timeZone,
  onSelect,
}: {
  readonly section: JourneySection;
  readonly index: number;
  readonly selected: boolean;
  readonly locale: string;
  readonly timeZone: string;
  readonly onSelect: () => void;
}): ReactNode {
  const routeColor = section.route
    ? cssColor(section.route.color, sectionTypeColors[section.type])
    : sectionTypeColors[section.type];
  const title = section.route
    ? `${section.route.shortName} · ${section.direction ?? section.route.longName}`
    : sectionTypeLabels[section.type];

  return (
    <li>
      <button
        type="button"
        onClick={onSelect}
        aria-current={selected ? "step" : undefined}
        className={cn(
          "focus-ring flex w-full items-start gap-3 rounded-2xl border p-3 text-left transition-colors",
          selected
            ? "border-accent bg-card-secondary"
            : "border-transparent bg-muted/45 hover:bg-muted",
        )}
      >
        {section.route ? (
          <LineBadge
            line={{
              shortName: section.route.shortName,
              color: routeColor,
              textColor: cssColor(section.route.textColor, "#ffffff"),
            }}
            className="mt-0.5 size-9 rounded-xl text-xs"
          />
        ) : (
          <span
            className="mt-0.5 grid size-9 shrink-0 place-items-center rounded-xl text-xs font-bold text-white"
            style={{ backgroundColor: routeColor }}
          >
            <Footprints className="size-4" />
          </span>
        )}
        <span className="min-w-0 flex-1">
          <span className="block truncate text-sm font-semibold">{title}</span>
          <span className="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-muted-foreground">
            <span>
              {section.from.name} → {section.to.name}
            </span>
            <span aria-hidden="true">·</span>
            <span>{formatDuration(section.durationSeconds)}</span>
          </span>
          {(section.departureAt || section.arrivalAt) && (
            <span className="mt-1 block text-xs font-medium text-foreground">
              {section.departureAt
                ? formatTime(section.departureAt, locale, timeZone)
                : "—"}
              {" → "}
              {section.arrivalAt
                ? formatTime(section.arrivalAt, locale, timeZone)
                : "—"}
            </span>
          )}
        </span>
        <span className="mt-1 text-xs font-medium text-muted-foreground">
          {index + 1}
        </span>
      </button>
    </li>
  );
}

function Stat({
  label,
  value,
}: {
  readonly label: string;
  readonly value: string;
}): ReactNode {
  return (
    <div className="px-2 text-center first:pl-0 last:pr-0">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="mt-1 text-sm font-semibold">{value}</p>
    </div>
  );
}

function LoadingState(): ReactNode {
  return (
    <main className="min-h-svh bg-background p-4 sm:p-6">
      <div className="mx-auto grid min-h-[calc(100svh-2rem)] max-w-[1440px] gap-4 lg:grid-cols-[1.15fr_0.85fr]">
        <div className="min-h-[50svh] animate-pulse rounded-[1.75rem] bg-muted" />
        <div className="rounded-[1.75rem] border bg-background p-6">
          <div className="h-4 w-32 animate-pulse rounded bg-muted" />
          <div className="mt-4 h-12 max-w-md animate-pulse rounded bg-muted" />
          <div className="mt-8 h-20 animate-pulse rounded-2xl bg-muted" />
          <div className="mt-8 space-y-3">
            {[1, 2, 3].map((item) => (
              <div
                key={item}
                className="h-20 animate-pulse rounded-2xl bg-muted"
              />
            ))}
          </div>
        </div>
      </div>
    </main>
  );
}

function JourneyShareErrorState({
  code,
  onRetry,
}: {
  readonly code: JourneyShareErrorCode;
  readonly onRetry: () => void;
}): ReactNode {
  // « Réessayer » se déduit du cas, il ne se réénumère pas : un sixième code
  // écrit ici arrive avec son texte *et* avec sa réponse à la question.
  const { title, body, permanent } = {
    journey_share_not_found: {
      title: "Trajet introuvable",
      body: "Ce lien ne correspond à aucun trajet partagé.",
      permanent: true,
    },
    journey_share_expired: {
      title: "Lien expiré",
      body: "Ce lien de trajet n’est plus disponible.",
      permanent: true,
    },
    journey_share_revoked: {
      title: "Lien supprimé",
      body: "L’expéditeur a supprimé ce trajet partagé.",
      permanent: true,
    },
    journey_share_unavailable: {
      title: "Trajet indisponible",
      body: "Le trajet ne peut pas être chargé pour le moment.",
      permanent: false,
    },
    unavailable: {
      title: "Connexion impossible",
      body: "Vérifiez votre connexion puis réessayez.",
      permanent: false,
    },
  }[code];

  return (
    <main className="grid min-h-svh place-items-center bg-background p-6">
      <section className="w-full max-w-md rounded-[1.75rem] border bg-background p-8 text-center shadow-sm">
        <div className="mx-auto grid size-14 place-items-center rounded-2xl bg-muted text-muted-foreground">
          {permanent ? (
            <Share2 className="size-6" />
          ) : (
            <RefreshCw className="size-6" />
          )}
        </div>
        <h1 className="mt-6 text-2xl font-semibold tracking-tight">{title}</h1>
        <p className="mt-3 text-sm leading-6 text-muted-foreground">{body}</p>
        <div className="mt-7 flex flex-col gap-3 sm:flex-row sm:justify-center">
          {!permanent && (
            <Button type="button" onClick={onRetry}>
              <RefreshCw />
              Réessayer
            </Button>
          )}
          <Link
            href="/"
            className="focus-ring inline-flex min-h-10 items-center justify-center rounded-md border px-4 text-sm font-medium hover:bg-muted"
          >
            Découvrir Metyro
          </Link>
        </div>
      </section>
    </main>
  );
}

function mapConfiguration(points: readonly MapCoordinate[]) {
  const fallback: MapCoordinate = [2.3522, 48.8566];
  if (points.length === 0) {
    return { center: fallback, zoom: 12, minZoom: 4, maxZoom: 18 };
  }
  const longitudes = points.map(([longitude]) => longitude);
  const latitudes = points.map(([, latitude]) => latitude);
  const span = Math.max(
    Math.max(...longitudes) - Math.min(...longitudes),
    Math.max(...latitudes) - Math.min(...latitudes),
  );
  return {
    center: [
      (Math.min(...longitudes) + Math.max(...longitudes)) / 2,
      (Math.min(...latitudes) + Math.max(...latitudes)) / 2,
    ] as MapCoordinate,
    zoom: span > 1 ? 9 : span > 0.25 ? 11 : span > 0.08 ? 12.5 : 14,
    minZoom: 4,
    maxZoom: 18,
  };
}

function toMapCoordinate(coordinate: Coordinate): MapCoordinate {
  return [coordinate.longitude, coordinate.latitude];
}

function cssColor(value: string, fallback: string): string {
  const normalized = value.trim();
  if (!normalized) return fallback;
  return normalized.startsWith("#") ? normalized : `#${normalized}`;
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(Math.max(value, minimum), maximum);
}

function journeyStatusLabel(
  status: JourneyShareResponse["snapshot"]["journey"]["status"],
): string {
  return status === "disrupted"
    ? "Perturbé"
    : status === "theoretical"
      ? "Théorique"
      : "Normal";
}

/**
 * Construire un `Intl.DateTimeFormat` coûte la résolution de la locale et du
 * fuseau ; l’afficher ne coûte rien. Un trajet de huit tronçons en demandait
 * seize par rendu, et chaque clic sur une étape rendait toute la liste. La
 * locale et le fuseau viennent de l’instantané, donc le jeu de formateurs est
 * fini : on le garde.
 *
 * Un objet nu, et non une `Map` : dans ce fichier `Map` est le composant de
 * carte.
 */
const formatterCache: Record<string, Intl.DateTimeFormat> = {};

function formatter(
  locale: string,
  timeZone: string,
  options: Intl.DateTimeFormatOptions,
): Intl.DateTimeFormat {
  const key = `${locale}|${timeZone}|${JSON.stringify(options)}`;
  return (formatterCache[key] ??= new Intl.DateTimeFormat(locale, {
    ...options,
    timeZone,
  }));
}

function formatDateRange(
  start: string,
  end: string,
  locale: string,
  timeZone: string,
): string {
  const long = formatter(locale, timeZone, {
    weekday: "long",
    day: "numeric",
    month: "long",
    hour: "2-digit",
    minute: "2-digit",
  });
  return `${long.format(new Date(start))} → ${formatTime(end, locale, timeZone)}`;
}

function formatDate(value: string, locale: string, timeZone: string): string {
  return formatter(locale, timeZone, {
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(new Date(value));
}

function formatTime(value: string, locale: string, timeZone: string): string {
  return formatter(locale, timeZone, {
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

function safeLocale(value: string): string {
  try {
    new Intl.DateTimeFormat(value);
    return value;
  } catch {
    return "fr-FR";
  }
}

function safeTimeZone(value: string): string {
  try {
    new Intl.DateTimeFormat("en", { timeZone: value });
    return value;
  } catch {
    return "Europe/Paris";
  }
}
