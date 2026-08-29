# Plan 020: Déclarer le français dans le document HTML et toutes les métadonnées Open Graph

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « STOP » se produit, arrêter et remonter le problème sans
> improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/marketing/src/constants/locale.ts apps/marketing/src/lib/locale.test.ts apps/marketing/src/app/layout.tsx apps/marketing/src/lib/metadata.ts`
> Si le layout racine, les helpers de métadonnées ou la stratégie de localisation
> ont changé, comparer les extraits ci-dessous au code courant. Une nouvelle
> locale produit est une condition STOP jusqu’à décision explicite.

## Statut

- **Priorité** : P2
- **Effort** : S
- **Risque** : LOW — correction déclarative avec tests purs, sans changement de contenu ni de route
- **Dépend de** : aucun autre plan
- **Catégorie** : bug / docs
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

Toutes les pages, les formats de date et les métadonnées App Store de Metyro
sont français, mais le document racine annonce `lang="en"` et la métadonnée Open
Graph de base annonce `en_US`. Les lecteurs d’écran peuvent donc choisir une
prononciation anglaise et les crawlers reçoivent un signal contradictoire. Ce
plan établit une petite source de vérité (`fr` pour HTML, `fr-FR` pour BCP 47 et
`fr_FR` pour Open Graph), l’applique aux métadonnées de base, de page et
d’article, puis verrouille ces trois sorties par test.

## État actuel

### Fichiers et responsabilités

- `apps/marketing/src/app/layout.tsx` — document HTML racine de toutes les routes.
- `apps/marketing/src/lib/metadata.ts` — métadonnées de base, pages génériques et articles.
- `apps/marketing/src/lib/blog/structured-data.ts` — donnée structurée article déjà correctement déclarée en `fr-FR`, exemple à suivre.
- `app-marketing-context.md` — décision produit : app et fiche uniquement françaises.

### Extraits à reconnaître avant modification

`apps/marketing/src/app/layout.tsx:32-42` :

```tsx
export default function RootLayout({ children }: ...): ReactNode {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>{/* providers */}</body>
    </html>
  );
}
```

`apps/marketing/src/lib/metadata.ts:28-38` :

```ts
openGraph: {
  type: "website",
  locale: "en_US",
  url: metadata.url,
  // ...
},
```

`createPageMetadata` aux lignes 55-79 construit un nouvel objet `openGraph`
sans `locale`. Comme les objets de métadonnées imbriqués peuvent remplacer la
valeur parente lors de la fusion Next, la correction doit être répétée via une
constante partagée dans cet objet, pas seulement dans `baseMetadata`.

`createArticleMetadata:104-115` possède déjà la bonne valeur, mais en littéral :

```ts
openGraph: {
  type: "article",
  locale: "fr_FR",
  // ...
}
```

`apps/marketing/src/lib/blog/structured-data.ts:29-36` est cohérent :

```ts
{
  "@type": "Article",
  inLanguage: "fr-FR",
}
```

`app-marketing-context.md:19-21` et `:107-118` documentent : version encore en
préparation, locale principale `fr-FR`, application et fiche monolingues
françaises.

### Contraintes de format

- Attribut HTML : utiliser un tag BCP 47 valide. `fr` est suffisant et exprime
  la langue du document sans inventer une variante de contenu régionale.
- Données structurées et APIs `Intl` : utiliser `fr-FR`.
- Open Graph : utiliser la forme attendue par le protocole, `fr_FR`.
- Ne pas utiliser `en_US`, ni mélanger tiret et underscore entre ces contextes.
- La locale est statique au build : ne pas ajouter de détection navigateur,
  cookie, middleware ou segment d’URL.
- Conserver `suppressHydrationWarning`, les polices, providers et classes du
  layout inchangés.

## Commandes utiles

| But               | Commande                                                                             | Résultat attendu     |
| ----------------- | ------------------------------------------------------------------------------------ | -------------------- |
| Tests ciblés      | `bun test apps/marketing/src/lib/locale.test.ts`                                     | tous les cas passent |
| Tests marketing   | `bun run --filter=@via/marketing test`                                               | tous passent         |
| Typecheck         | `bun run --filter=@via/marketing typecheck`                                          | exit 0               |
| Lint              | `bun run --filter=@via/marketing lint`                                               | exit 0               |
| Build             | `bun run --filter=@via/marketing build`                                              | exit 0               |
| Anciennes valeurs | `if rg -n -e 'lang="en"' -e 'locale:\s*"en_US"' apps/marketing/src; then exit 1; fi` | exit 0               |

## Périmètre

### Fichiers autorisés

- `apps/marketing/src/constants/locale.ts` (nouveau)
- `apps/marketing/src/lib/locale.test.ts` (nouveau)
- `apps/marketing/src/app/layout.tsx`
- `apps/marketing/src/lib/metadata.ts`
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- `app-marketing-context.md` et `lib/blog/structured-data.ts`, qui servent de
  preuve et sont déjà corrects.
- La traduction de l’app ou du site et l’ajout de l’anglais.
- Des routes localisées, `hreflang`, middleware de locale ou sélecteur de langue.
- Les formats de date/nombre déjà explicitement `fr-FR`.
- Le manifest PWA, les métadonnées App Store et le flux RSS déjà français.
- Les titres, descriptions, mots-clés et contenus éditoriaux.

## Git

- Branche recommandée : `codex/020-declare-french-site-locale`.
- Commits logiques, par exemple
  `fix(marketing): declare the French site locale`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Écrire une source de vérité adaptée aux trois syntaxes

Créer `apps/marketing/src/constants/locale.ts` avec un objet immuable et des
noms qui rendent toute confusion visible :

```ts
export const siteLocale = {
  htmlLanguage: "fr",
  bcp47: "fr-FR",
  openGraph: "fr_FR",
} as const;
```

Ne pas dériver naïvement Open Graph avec `replace("-", "_")` : si une future
locale change, la forme et la politique devront être relues explicitement.
`bcp47` existe pour les données structurées/formateurs futurs même si le seul
nouvel appel de ce plan utilise surtout HTML et Open Graph.

**Vérifier** : `bun run --filter=@via/marketing typecheck` → exit 0.

### 2. Corriger la langue du document racine

Importer `siteLocale` dans `app/layout.tsx` et remplacer seulement l’attribut :

```tsx
<html lang={siteLocale.htmlLanguage} suppressHydrationWarning>
```

Ne déplacer aucun provider, ne modifier aucune classe, aucune police et aucun
objet viewport.

**Vérifier** :

```bash
rg -n 'lang=\{siteLocale\.htmlLanguage\}' apps/marketing/src/app/layout.tsx
```

Résultat attendu : une occurrence.

### 3. Corriger toutes les fabriques Open Graph

Importer `siteLocale` dans `lib/metadata.ts` et utiliser
`locale: siteLocale.openGraph` dans :

1. `baseMetadata.openGraph` ;
2. l’objet `openGraph` retourné par `createPageMetadata` ;
3. l’objet `openGraph` retourné par `createArticleMetadata`.

Le troisième remplacement élimine le littéral `fr_FR` déjà correct afin qu’une
future décision de locale ne crée pas deux sources. Le helper de page doit
déclarer sa locale lui-même pour ne pas dépendre des détails de fusion de Next.

Ne changer aucun canonical, image, date, type `website/article` ou robot.

**Vérifier** :

```bash
rg -n 'locale: siteLocale\.openGraph' apps/marketing/src/lib/metadata.ts
```

Résultat attendu : exactement trois occurrences.

### 4. Tester les valeurs et les trois sorties de métadonnées

Créer `apps/marketing/src/lib/locale.test.ts` avec `bun:test`. Importer
`siteLocale`, `baseMetadata`, `createPageMetadata` et `createArticleMetadata`.
Tester :

- `htmlLanguage === "fr"` ;
- `bcp47 === "fr-FR"` ;
- `openGraph === "fr_FR"` ;
- `baseMetadata.openGraph` contient `locale: "fr_FR"` ;
- `createPageMetadata({ title: "Test", path: "/test" }).openGraph` contient la même locale ;
- `createArticleMetadata` avec dates ISO sentinelles contient la même locale et
  conserve `type: "article"` ;
- le source de `app/layout.tsx`, lu via une URL relative à `import.meta.url`,
  référence `siteLocale.htmlLanguage` et ne contient plus `lang="en"`.

Pour les unions du type `Metadata`, utiliser `expect(...).toMatchObject(...)`
plutôt que des casts permissifs. Les tests ne doivent pas rendre le layout :
importer `next/font/google` dans Bun ajouterait un bruit sans rapport à cette
valeur déclarative.

**Vérifier** : `bun test apps/marketing/src/lib/locale.test.ts` → sept assertions/familles passent.

### 5. Exécuter la non-régression marketing

Lancer toute la suite et le build. La sortie générée doit garder les mêmes
routes. Inspecter au besoin le HTML de `/` dans le build/dev local : la balise
racine porte `lang="fr"`. Les métadonnées d’une page générique et d’un article
doivent contenir `og:locale` avec `fr_FR`.

**Vérifier** :

```bash
bun run --filter=@via/marketing test
bun run --filter=@via/marketing typecheck
bun run --filter=@via/marketing lint
bun run --filter=@via/marketing build
if rg -n 'lang="en"|locale:\s*"en_US"' apps/marketing/src; then exit 1; fi
```

Résultat attendu : toutes les commandes sortent 0 et aucune ancienne valeur
n’est trouvée.

## Plan de test

- Nouveau `locale.test.ts`, sans renderer ni réseau : trois syntaxes de locale,
  trois fabriques Open Graph et câblage source du layout.
- `toMatchObject` vérifie les sorties Next réellement exportées, pas seulement
  la constante.
- La suite marketing garantit que les helpers de blog et le partage de trajet
  ne régressent pas.
- Le build Next garantit que l’import de constante fonctionne depuis le Server
  Component racine et la couche metadata.
- Contrôle `rg` négatif sur les deux anciennes déclarations anglaises.

## Critères de fin

- [ ] Le document racine rend `lang="fr"` via `siteLocale.htmlLanguage`.
- [ ] La constante distingue `fr`, `fr-FR` et `fr_FR` par contexte.
- [ ] Base, pages génériques et articles déclarent tous `og:locale = fr_FR`.
- [ ] Aucun `lang="en"` ni `locale: "en_US"` ne subsiste dans le code marketing.
- [ ] Les tests ciblés couvrent les constantes, les trois métadonnées et le câblage layout.
- [ ] Tests, typecheck, lint et build marketing sortent 0.
- [ ] Aucun contenu, route, provider ou format existant n’a changé.
- [ ] Aucun fichier hors périmètre n’est modifié, hormis le statut dans `plans/README.md`.

## Conditions STOP

Arrêter et remonter le problème si :

- le produit ou le site possède désormais une seconde locale réellement
  publiée ; ce cas exige une stratégie de routage/hreflang, pas une constante
  globale ;
- un ADR ou document plus récent remplace la contrainte monolingue française ;
- Next a changé la forme de `Metadata.openGraph.locale` dans la version installée ;
- importer la constante dans le layout force le fichier à devenir un Client Component ;
- corriger la locale exige de modifier les URLs, le contenu ou les métadonnées App Store ;
- un test/build échoue deux fois après correction raisonnable ;
- un fichier hors périmètre doit être modifié.

## Notes de maintenance

- Toute future localisation doit modifier ensemble HTML, Open Graph, données
  structurées, RSS, formats et routes. Ne changer qu’une des trois valeurs de
  `siteLocale` serait un signal de design incomplet.
- Open Graph emploie un underscore quand BCP 47 emploie un tiret ; les deux
  formes sont intentionnelles et doivent rester testées séparément.
- En review, vérifier spécialement `createPageMetadata` : une métadonnée imbriquée
  construite par page ne doit pas perdre la locale de base.
- La bonne déclaration aide l’accessibilité et les crawlers ; elle ne remplace
  pas une future localisation réelle du contenu.
