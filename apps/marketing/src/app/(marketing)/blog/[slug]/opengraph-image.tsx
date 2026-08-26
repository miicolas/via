import { transitLines } from "@/constants/transit";
import { findArticle, loadArticles } from "@/lib/blog/loader";
import { buildLineStrip } from "@/lib/blog/line-strip-data";
import { ImageResponse } from "next/og";

export const size = { width: 1200, height: 630 };
export const contentType = "image/png";
export const alt = "Travaux et trafic sur le réseau francilien";

export async function generateStaticParams(): Promise<Array<{ slug: string }>> {
  const articles = await loadArticles();
  return articles.map((article) => ({ slug: article.slug }));
}

/**
 * La vignette partagée d’un article.
 *
 * Elle montre le tronçon coupé aux couleurs de la ligne, ce qui la rend
 * reconnaissable d’un coup d’œil dans un fil ou une conversation — là où la
 * vignette générique du site ne dirait rien de quelle ligne est concernée.
 *
 * Écrite en styles en ligne : Satori, qui la dessine, ne connaît ni Tailwind ni
 * les variables CSS. Le nombre d’arrêts est réduit à ce qui reste lisible à
 * 1200 px, centré sur ce qui est fermé.
 */
export default async function Image({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<ImageResponse> {
  const { slug } = await params;
  const article = await findArticle(slug);

  const frontmatter = article?.frontmatter;
  const key = frontmatter?.lines[0];
  const reference = key ? transitLines[key] : null;
  const accent = reference?.color ?? "#1872f7";

  const stops = key && frontmatter ? previewStops(key, frontmatter) : [];

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          backgroundColor: "#0a0a0a",
          padding: 72,
          fontFamily: "sans-serif",
        }}
      >
        <div style={{ display: "flex", alignItems: "center" }}>
          {reference && (
            <div
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                width: 84,
                height: 84,
                borderRadius: 22,
                backgroundColor: reference.color,
                color: reference.textColor,
                fontSize: 44,
                fontWeight: 700,
              }}
            >
              {reference.shortName}
            </div>
          )}
          <div
            style={{
              marginLeft: 24,
              color: "#a3a3a3",
              fontSize: 26,
              letterSpacing: 2,
              textTransform: "uppercase",
            }}
          >
            Travaux &amp; trafic
          </div>
        </div>

        <div
          style={{
            display: "flex",
            color: "#fafafa",
            fontSize: 58,
            lineHeight: 1.15,
            fontWeight: 500,
            maxWidth: 1000,
          }}
        >
          {frontmatter?.title ?? "Travaux sur le réseau francilien"}
        </div>

        {stops.length > 0 && (
          <div style={{ display: "flex", alignItems: "flex-start" }}>
            {stops.map((stop, index) => (
              <div
                key={`${stop.name}-${index}`}
                style={{
                  display: "flex",
                  flexDirection: "column",
                  alignItems: "center",
                  width: 1056 / stops.length,
                }}
              >
                {/* Le rail est fait de deux demi-segments de part et d’autre
                    du point : sans lui, la bande se lit comme une rangée de
                    pastilles et non comme une ligne. */}
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    height: 22,
                    width: "100%",
                  }}
                >
                  <div
                    style={{
                      flexGrow: 1,
                      height: 5,
                      backgroundColor: index === 0 ? "transparent" : accent,
                    }}
                  />
                  <div
                    style={{
                      width: 22,
                      height: 22,
                      borderRadius: 11,
                      backgroundColor: stop.closed ? "#0a0a0a" : accent,
                      border: `4px solid ${stop.closed ? "#fafafa" : accent}`,
                    }}
                  />
                  <div
                    style={{
                      flexGrow: 1,
                      height: 5,
                      backgroundColor: index === stops.length - 1 ? "transparent" : accent,
                    }}
                  />
                </div>
                <div
                  style={{
                    marginTop: 14,
                    color: stop.closed ? "#fafafa" : "#8a8a8a",
                    fontSize: 19,
                    textAlign: "center",
                    display: "flex",
                  }}
                >
                  {stop.name}
                </div>
              </div>
            ))}
          </div>
        )}

        <div style={{ display: "flex", color: "#737373", fontSize: 26 }}>
          metyro.app
        </div>
      </div>
    ),
    size,
  );
}

const PREVIEW_WIDTH = 7;

/**
 * Sept arrêts au plus. Au-delà les noms se chevauchent, et une vignette
 * illisible ne vaut pas mieux qu’aucune.
 *
 * La fenêtre retenue est celle qui montre le plus de stations fermées, et non
 * celle centrée sur elles : sur une ligne à branches comme la 13, les stations
 * fermées peuvent être éloignées dans la bande aplatie, et le milieu tombe
 * alors sur un endroit où il ne se passe rien.
 */
function previewStops(
  key: keyof typeof transitLines,
  frontmatter: NonNullable<Awaited<ReturnType<typeof findArticle>>>["frontmatter"],
): Array<{ name: string; closed: boolean }> {
  try {
    const strip = buildLineStrip({
      line: key,
      impactedSections: frontmatter.impactedSections,
      declaredStops: frontmatter.declaredStops,
    });

    if (strip.stops.length <= PREVIEW_WIDTH) {
      return strip.stops.map((stop) => ({ name: stop.name, closed: stop.state === "closed" }));
    }

    let best = 0;
    let bestCount = -1;
    for (let start = 0; start + PREVIEW_WIDTH <= strip.stops.length; start += 1) {
      const count = strip.stops
        .slice(start, start + PREVIEW_WIDTH)
        .filter((stop) => stop.state === "closed").length;
      if (count > bestCount) {
        bestCount = count;
        best = start;
      }
    }

    return strip.stops
      .slice(best, best + PREVIEW_WIDTH)
      .map((stop) => ({ name: stop.name, closed: stop.state === "closed" }));
  } catch {
    // Une vignette ne doit jamais faire échouer un build : sans schéma, elle
    // se contente du titre.
    return [];
  }
}
