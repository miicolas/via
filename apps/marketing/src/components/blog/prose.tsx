import { TransitText } from "@/components/ui/transit-text";
import { Children, type ReactNode } from "react";

/**
 * La typographie du corps d’article, composant par composant.
 *
 * Pas de `@tailwindcss/typography` : le design du site est trop caractérisé —
 * cadre décoratif, tokens `--frame` et `--accent`, Geist — pour qu’un `prose`
 * générique s’y fonde, et il aurait fallu écrire les mappings de composants de
 * toute façon pour les alertes et les schémas. Autant que `h2` et `p` en
 * fassent partie.
 */

interface ProseProps {
  readonly children?: ReactNode;
  readonly id?: string;
}

/**
 * Chaque fragment de texte brut passe par `TransitText`, qui remplace « ligne 4 »,
 * « RER B » et les noms de stations par leur logo, exactement comme dans l’app.
 * Les nœuds déjà rendus — un lien, un mot en gras — sont laissés intacts : ils
 * ont leur propre composant, qui fera la même chose sur son propre texte.
 */
function withTransitText(children: ReactNode): ReactNode {
  return Children.map(children, (child) =>
    typeof child === "string" ? <TransitText>{child}</TransitText> : child,
  );
}

/*
 * Les titres ne passent pas par `TransitText`. Un logo de ligne se lit bien au
 * fil d’une phrase et détruit un titre : la pastille casse l’interligne, et
 * « République » suivi de ses cinq logos n’est plus une phrase qu’on lit, c’est
 * une rangée d’icônes. Les titres restent du texte.
 */
export const proseComponents = {
  h2: ({ children, id }: ProseProps) => (
    <h2
      id={id}
      className="mt-14 scroll-mt-32 text-2xl leading-tight font-medium tracking-tight text-balance text-foreground sm:text-3xl"
    >
      {children}
    </h2>
  ),

  h3: ({ children, id }: ProseProps) => (
    <h3
      id={id}
      className="mt-10 scroll-mt-32 text-xl leading-snug font-medium tracking-tight text-foreground"
    >
      {children}
    </h3>
  ),

  h4: ({ children, id }: ProseProps) => (
    <h4 id={id} className="mt-8 scroll-mt-32 font-semibold text-foreground">
      {children}
    </h4>
  ),

  p: ({ children }: ProseProps) => (
    <p className="mt-5 leading-8 text-foreground/90">{withTransitText(children)}</p>
  ),

  ul: ({ children }: ProseProps) => (
    <ul className="mt-5 space-y-2.5 pl-5 [&>li]:list-disc [&>li]:marker:text-foreground/30">
      {children}
    </ul>
  ),

  ol: ({ children }: ProseProps) => (
    <ol className="mt-5 space-y-2.5 pl-5 [&>li]:list-decimal [&>li]:marker:text-muted-foreground">
      {children}
    </ol>
  ),

  li: ({ children }: ProseProps) => (
    <li className="leading-8 text-foreground/90">{withTransitText(children)}</li>
  ),

  a: ({ children, href }: ProseProps & { readonly href?: string }) => {
    // Un lien sortant ne transmet pas l’autorité du domaine et s’ouvre à côté.
    const isExternal = href?.startsWith("http") === true;
    return (
      <a
        href={href}
        className="focus-ring text-foreground underline decoration-accent/50 underline-offset-4 transition-colors hover:decoration-accent"
        {...(isExternal ? { rel: "nofollow noopener", target: "_blank" } : {})}
      >
        {withTransitText(children)}
      </a>
    );
  },

  strong: ({ children }: ProseProps) => (
    <strong className="font-semibold text-foreground">{withTransitText(children)}</strong>
  ),

  em: ({ children }: ProseProps) => <em className="italic">{withTransitText(children)}</em>,

  blockquote: ({ children }: ProseProps) => (
    <blockquote className="my-8 border-l-2 border-foreground/15 pl-5 text-foreground/75 italic">
      {children}
    </blockquote>
  ),

  hr: () => <hr className="my-12 border-foreground/10" />,

  /* Un tableau déborde vite : il défile dans son conteneur, jamais la page. */
  table: ({ children }: ProseProps) => (
    <div className="my-8 overflow-x-auto">
      <table className="w-full min-w-max border-collapse text-left text-sm">{children}</table>
    </div>
  ),

  thead: ({ children }: ProseProps) => (
    <thead className="border-b border-foreground/15">{children}</thead>
  ),

  tbody: ({ children }: ProseProps) => (
    <tbody className="divide-y divide-foreground/10">{children}</tbody>
  ),

  th: ({ children }: ProseProps) => (
    <th className="px-3 py-2.5 font-semibold text-foreground first:pl-0 last:pr-0">
      {withTransitText(children)}
    </th>
  ),

  td: ({ children }: ProseProps) => (
    <td className="px-3 py-2.5 align-top leading-7 text-foreground/90 first:pl-0 last:pr-0">
      {withTransitText(children)}
    </td>
  ),

  code: ({ children }: ProseProps) => (
    <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-[0.9em] text-foreground">
      {children}
    </code>
  ),

  pre: ({ children }: ProseProps) => (
    <pre className="my-8 overflow-x-auto rounded-2xl bg-muted p-5 font-mono text-sm">
      {children}
    </pre>
  ),
};
