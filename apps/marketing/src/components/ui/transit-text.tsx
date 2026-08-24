import {
  metroLineByNumber,
  rerLineByLetter,
  stationLines,
  type TransitLineRef,
} from "@/constants/transit";
import type { ReactNode } from "react";

/** Espace simple, insécable ou fine insécable — les trois vivent dans les textes français. */
const SPACE = String.raw`[\s\u00a0\u202f]`;

const STATION_PATTERN = Object.keys(stationLines)
  .sort((a, b) => b.length - a.length)
  .map((name) => name.replace(/[.*+?^${}()|[\]\\]/g, String.raw`\$&`))
  .join("|");

const TOKEN_PATTERN = new RegExp(
  `RER${SPACE}(?<rer>[A-E])(?![\\p{L}\\d])|` +
    `[Ll]igne${SPACE}(?<metro>\\d{1,2})(?![\\p{L}\\d])|` +
    `(?<exitWord>[Ss]ortie)${SPACE}(?<exitNumber>\\d{1,2})(?![\\p{L}\\d])|` +
    `(?<station>${STATION_PATTERN})`,
  "gu",
);

/** Logo de ligne à hauteur de texte, dimensionné en em pour suivre la typographie qui l’entoure. */
function InlineBadge({
  label,
  color,
  textColor,
}: {
  readonly label: string;
  readonly color: string;
  readonly textColor: string;
}): ReactNode {
  return (
    <span
      className="inline-grid h-[1.3em] min-w-[1.3em] shrink-0 place-items-center rounded-[0.36em] px-[0.16em] align-[-0.3em] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.25)]"
      style={{ backgroundColor: color, color: textColor }}
    >
      <span className="text-[0.72em] leading-none font-bold tabular-nums">
        {label}
      </span>
    </span>
  );
}

/** La rangée de petits logos qui suit un nom de station, comme dans l’app. */
function StationLineBadges({
  lines,
}: {
  readonly lines: readonly TransitLineRef[];
}): ReactNode {
  return (
    <span
      className="inline-flex shrink-0 items-center gap-[0.18em]"
      aria-hidden="true"
    >
      {lines.map((line) => (
        <span
          key={`${line.mode}-${line.shortName}`}
          className="inline-grid h-[1.1em] min-w-[1.1em] place-items-center rounded-[0.3em] px-[0.12em] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.25)]"
          style={{ backgroundColor: line.color, color: line.textColor }}
        >
          <span className="text-[0.58em] leading-none font-bold tabular-nums">
            {line.shortName}
          </span>
        </span>
      ))}
    </span>
  );
}

/** Le bleu signalétique des numéros de sortie sur les quais. */
const EXIT_BLUE = { color: "#003ca6", textColor: "#ffffff" };

/**
 * Rend une phrase en remplaçant les mentions de lignes, de RER, de sorties et de
 * stations connues par leur logo, comme le fait l’app.
 */
export function TransitText({
  children,
}: {
  readonly children: string;
}): ReactNode {
  const parts: ReactNode[] = [];
  let cursor = 0;

  for (const match of children.matchAll(TOKEN_PATTERN)) {
    const index = match.index;
    const groups = match.groups ?? {};
    let replacement: ReactNode = null;

    if (groups.metro !== undefined) {
      const line = metroLineByNumber[groups.metro];
      if (line) {
        replacement = (
          <span key={index}>
            <span className="sr-only">{match[0]}</span>
            <span aria-hidden="true">
              <InlineBadge
                label={line.shortName}
                color={line.color}
                textColor={line.textColor}
              />
            </span>
          </span>
        );
      }
    } else if (groups.rer !== undefined) {
      const line = rerLineByLetter[groups.rer];
      if (line) {
        replacement = (
          <span
            key={index}
            className="inline-flex items-center gap-[0.28em] whitespace-nowrap"
          >
            {"RER"}
            <InlineBadge
              label={line.shortName}
              color={line.color}
              textColor={line.textColor}
            />
          </span>
        );
      }
    } else if (groups.exitNumber !== undefined) {
      replacement = (
        <span
          key={index}
          className="inline-flex items-center gap-[0.28em] whitespace-nowrap"
        >
          {groups.exitWord}
          <InlineBadge label={groups.exitNumber} {...EXIT_BLUE} />
        </span>
      );
    } else if (groups.station !== undefined) {
      const lines = stationLines[groups.station];
      if (lines) {
        replacement = (
          <span
            key={index}
            className="inline-flex items-center gap-[0.35em] whitespace-nowrap"
          >
            {groups.station}
            <StationLineBadges lines={lines} />
          </span>
        );
      }
    }

    if (replacement === null) continue;
    if (index > cursor) parts.push(children.slice(cursor, index));
    parts.push(replacement);
    cursor = index + match[0].length;
  }

  if (parts.length === 0) return children;
  if (cursor < children.length) parts.push(children.slice(cursor));
  return <>{parts}</>;
}
