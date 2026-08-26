import type {
  LineStrip as LineStripData,
  StripGap,
  StripSegment,
} from "@/lib/blog/line-strip-data";
import type { CSSProperties, ReactNode } from "react";

/** Largeur d’une colonne de station : assez pour deux mots, assez serré pour en voir six. */
const COLUMN = "w-24 sm:w-28";

/** Le rail passe au centre des pastilles, qui font 17 px de haut. */
const RAIL_TOP = "top-[7px]";

/**
 * Le schéma d’une ligne, avec ses tronçons coupés et ses stations fermées.
 *
 * C’est le seul dessin d’un article de travaux, et il porte l’essentiel de ce
 * que le lecteur est venu chercher : jusqu’où ça roule. Il est rendu côté
 * serveur, sans dépendance réseau, à partir de l’instantané commité — une page
 * SEO ne doit jamais attendre une réponse pour montrer son illustration.
 *
 * Sur une ligne longue, seules les zones fermées sont dessinées, avec quelques
 * arrêts de contexte : une bande de quarante stations s’ouvre sur son terminus,
 * c’est-à-dire à l’opposé de ce qu’on est venu voir. Ce qui est escamoté est
 * compté, jamais tu.
 */
export function LineStrip({ strip }: { readonly strip: LineStripData }): ReactNode {
  return (
    <figure
      className="my-10"
      style={{ "--line": strip.color, "--line-text": strip.textColor } as CSSProperties}
    >
      <div
        className="overflow-x-auto pb-2"
        // Le dessin est décoratif pour un lecteur d’écran : la phrase du
        // `figcaption` dit la même chose, en mieux.
        role="group"
        aria-label={strip.description}
        tabIndex={0}
      >
        <div className="flex min-w-max items-start px-1" aria-hidden="true">
          {strip.segments.map((segment, index) => (
            <Segment key={index} segment={segment} />
          ))}
        </div>
      </div>

      {/*
        Les noms de branches vivent ici et non au-dessus des arrêts : certains
        font soixante-dix caractères, et aucune colonne ne les accueillera.
        En regard, la rupture du rail dit visuellement où la fourche se trouve.
      */}
      {strip.branches.length > 0 && (
        <p className="mt-3 text-xs leading-5 text-muted-foreground">
          La bande met bout à bout les branches de la ligne :{" "}
          {strip.branches.join(", ")}. Le rail s’interrompt à chaque fourche.
        </p>
      )}

      <figcaption className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2 text-xs text-muted-foreground">
        <span className="flex items-center gap-1.5">
          <span className="h-[3px] w-5 rounded-full bg-[var(--line)]" aria-hidden="true" />
          Circulation normale
        </span>
        <span className="flex items-center gap-1.5">
          <span
            className="h-[3px] w-5 rounded-full bg-[repeating-linear-gradient(90deg,var(--line)_0_3px,transparent_3px_7px)] opacity-70"
            aria-hidden="true"
          />
          Tronçon interrompu
        </span>
        <span className="flex items-center gap-1.5">
          <span
            className="grid size-3.5 place-items-center rounded-full border-2 border-foreground text-[8px] leading-none font-bold"
            aria-hidden="true"
          >
            ×
          </span>
          Station non desservie
        </span>
      </figcaption>
    </figure>
  );
}

function Segment({ segment }: { readonly segment: StripSegment }): ReactNode {
  return (
    <>
      {segment.gapBefore && <Gap gap={segment.gapBefore} side="before" />}

      <ol className="flex items-start">
        {segment.stops.map((stop, index) => {
          const isFirst = index === 0;
          const isLast = index === segment.stops.length - 1;

          return (
            <li
              key={`${stop.name}-${index}`}
              className={`relative flex ${COLUMN} shrink-0 flex-col items-center`}
            >
              {/*
                Aux extrémités d’un segment, le demi-rail continue vers la
                coupure : la bande ne doit pas sembler s’arrêter là. En
                revanche, un arrêt qui ouvre une nouvelle section n’est relié à
                rien vers la gauche — deux branches mises bout à bout ne se
                touchent pas dans la vraie vie.
              */}
              {(!isFirst || segment.gapBefore !== undefined) && !stop.startsSection && (
                <Rail side="left" cut={index > 0 && segment.cut[index - 1] === true} />
              )}
              {(!isLast || segment.gapAfter !== undefined) &&
                segment.stops[index + 1]?.startsSection !== true && (
                  <Rail side="right" cut={segment.cut[index] === true} />
                )}

              <StopMarker state={stop.state} isInterchange={stop.isInterchange} />

              <span
                className={`mt-3 text-center text-[11px] leading-tight ${
                  stop.state === "closed"
                    ? "font-semibold text-foreground line-through decoration-2"
                    : "text-muted-foreground"
                }`}
              >
                {stop.name}
              </span>
            </li>
          );
        })}
      </ol>

      {segment.gapAfter && <Gap gap={segment.gapAfter} side="after" />}
    </>
  );
}

/**
 * Ce qui n’est pas dessiné, dit explicitement.
 *
 * « … 14 stations · Balard » vaut mieux qu’une bande qui semble finir là où
 * elle a été coupée : le lecteur sait qu’il ne manque rien d’important, et il
 * sait où va la ligne.
 */
function Gap({ gap, side }: { readonly gap: StripGap; readonly side: "before" | "after" }): ReactNode {
  return (
    <div className="relative flex w-20 shrink-0 flex-col items-center sm:w-24">
      <span
        className={`absolute ${RAIL_TOP} left-0 h-[3px] w-full bg-[repeating-linear-gradient(90deg,var(--line)_0_2px,transparent_2px_6px)] opacity-40`}
      />
      <span className="relative z-10 flex h-[17px] items-center text-sm leading-none text-muted-foreground">
        ···
      </span>
      <span className="mt-3 text-center text-[11px] leading-tight text-muted-foreground">
        {gap.hidden} station{gap.hidden > 1 ? "s" : ""}
        {gap.terminus !== undefined && (
          <>
            <br />
            {side === "before" ? "depuis " : "jusqu’à "}
            {gap.terminus}
          </>
        )}
      </span>
    </div>
  );
}

/**
 * Une moitié de rail. Le pointillé n’est pas qu’un style : c’est la convention
 * des plans de quai pour « ça ne roule pas ici », et un lecteur francilien la
 * connaît déjà.
 */
function Rail({ side, cut }: { readonly side: "left" | "right"; readonly cut: boolean }): ReactNode {
  const position = side === "left" ? "left-0" : "right-0";
  const appearance = cut
    ? "bg-[repeating-linear-gradient(90deg,var(--line)_0_3px,transparent_3px_7px)] opacity-60"
    : "bg-[var(--line)]";

  return (
    <span
      className={`absolute ${position} ${RAIL_TOP} h-[3px] w-1/2 ${appearance}`}
      aria-hidden="true"
    />
  );
}

function StopMarker({
  state,
  isInterchange,
}: {
  readonly state: "served" | "closed";
  readonly isInterchange: boolean;
}): ReactNode {
  if (state === "closed") {
    return (
      <span className="relative z-10 grid size-[17px] place-items-center rounded-full border-2 border-foreground bg-background text-[10px] leading-none font-bold text-foreground">
        ×
      </span>
    );
  }

  // Une correspondance se dessine en blanc cerclé, comme sur les plans : c’est
  // là qu’un contournement peut commencer.
  return isInterchange ? (
    <span className="relative z-10 size-[17px] rounded-full border-[3px] border-[var(--line)] bg-background" />
  ) : (
    <span className="relative z-10 size-[11px] rounded-full bg-[var(--line)] ring-2 ring-background" />
  );
}
