# Plan 011: Rendre chaque appel au lancement vrai depuis une configuration unique

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « STOP » se produit, arrêter et remonter le problème sans
> improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/marketing/src/constants/launch.ts apps/marketing/src/constants/launch.test.ts apps/marketing/src/constants/page.ts apps/marketing/src/constants/analytics-page.ts apps/marketing/src/constants/navigation.ts apps/marketing/src/components/ui/launch-action.tsx apps/marketing/src/components/ui/app-store-badge-link.tsx apps/marketing/src/components/sections/hero/hero-copy.tsx apps/marketing/src/components/sections/analytics/analytics-hero.tsx apps/marketing/src/components/sections/analytics/analytics-download-section.tsx apps/marketing/src/components/layout/download-card.tsx apps/marketing/src/components/sections/faq/faq-section.tsx 'apps/marketing/src/app/trip/[token]/page.client.tsx'`
> Si un fichier du périmètre a changé, comparer les extraits ci-dessous au code
> courant. Une nouvelle destination de téléchargement, un changement de statut
> App Store ou une nouvelle surface de CTA doit être réconcilié avant exécution.

## Statut

- **Priorité** : P1
- **Effort** : M (état produit explicite, composant partagé et régression de toutes les surfaces)
- **Risque** : LOW — changement de contenu et de rendu sans modification de routage serveur
- **Dépend de** : aucun autre plan
- **Catégorie** : bug / direction
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

Le site dit « Disponible maintenant » et rend plusieurs badges App Store, mais
leur destination centrale est `#`; le lien d’assistance principal est lui aussi
`#`. Un voyageur clique donc sur les deux actions les plus importantes sans
quitter la page ni obtenir d’explication. Le dépôt connaît l’identifiant Apple
`6801259695`, mais son contexte du 25 août indique encore une version 1.0 en
`PREPARE_FOR_SUBMISSION`. Ce plan crée une seule configuration de lancement :
si l’app est publiée, toutes les surfaces pointent vers la vraie fiche ; si elle
est encore en préparation, aucun faux bouton de téléchargement n’est rendu et
un statut non interactif dit honnêtement qu’elle arrive bientôt.

## État actuel

### Fichiers et responsabilités

- `app-marketing-context.md` — dernier état App Store documenté et identifiant Apple.
- `apps/marketing/src/constants/page.ts` — copie principale de l’action App Store, badge hero, FAQ et footer.
- `apps/marketing/src/constants/analytics-page.ts` — seconde copie indépendante de la même action.
- `apps/marketing/src/constants/navigation.ts` — libellé global « Télécharger » qui descend vers le footer.
- `apps/marketing/src/components/ui/app-store-badge-link.tsx` — badge correct lorsqu’une vraie URL App Store existe.
- `apps/marketing/src/components/sections/hero/hero-copy.tsx` — rend toujours le badge de téléchargement.
- `apps/marketing/src/components/sections/analytics/analytics-hero.tsx` et `analytics-download-section.tsx` — deux autres badges.
- `apps/marketing/src/components/layout/download-card.tsx` et `components/sections/faq/faq-section.tsx` — rendent les actions génériques du contenu.
- `apps/marketing/src/app/trip/[token]/page.client.tsx` — contient une quatrième destination App Store indirecte, codée en dur vers `/#download`.

### Extraits à reconnaître avant modification

`apps/marketing/src/constants/page.ts:4-7` :

```ts
const appStoreAction = {
  label: "Télécharger Metyro",
  href: "#",
} satisfies CallToAction;
```

Le même objet est recopié dans `analytics-page.ts:3-6`.

`apps/marketing/src/constants/page.ts:13-16` annonce :

```ts
hero: {
  badge: "Disponible maintenant",
  // ...
}
```

`apps/marketing/src/constants/page.ts:42-46` contient aussi :

```ts
primaryAction: appStoreAction,
secondaryAction: {
  label: "Contacter l’assistance",
  href: "#",
}
```

`apps/marketing/src/app/trip/[token]/page.client.tsx:288-291` crée une copie
supplémentaire qui renvoie vers le faux téléchargement du footer :

```tsx
<AppStoreBadgeLink
  label="Télécharger Metyro sur l’App Store"
  href="/#download"
/>
```

`app-marketing-context.md:10-21` donne les faits disponibles :

```text
App ID (Apple): 6801259695
Launch Date: pas encore lancée — version 1.0 en PREPARE_FOR_SUBMISSION
Primary Locale: fr-FR
```

Le site possède déjà une vraie destination interne d’assistance :
`apps/marketing/src/constants/navigation.ts:44-47` pointe vers `/help`, et la
route est produite par `marketing-pages.ts` avec le slug `help`.

### Contraintes de conception

- Une destination de lancement n’est jamais inventée à partir du seul App ID.
  La fiche peut ne pas être publique malgré l’existence de l’app dans App Store
  Connect.
- Un état `prelaunch` ne rend pas un `<a>` ou un bouton inerte : il rend un texte
  de statut visible, par exemple « Bientôt disponible sur l’App Store ».
- Un état `available` rend le badge Apple existant avec une URL HTTPS réelle et
  testée. Ne pas remplacer le badge officiel par un bouton texte.
- Le deep link `via://trip/<token>` reste utile aux personnes qui possèdent déjà
  l’app (TestFlight compris) et reste hors de la décision de disponibilité.
- L’assistance publique passe par `/help` tant qu’une adresse de contact ou un
  service de tickets explicitement approuvé n’est pas documenté.
- Tous les contenus restent en français ; ne pas introduire de locale ou de
  variante Android/web mobile.

## Commandes utiles

| But             | Commande                                                                                                                      | Résultat attendu                |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| Tests ciblés    | `bun test apps/marketing/src/constants/launch.test.ts`                                                                        | tous les cas passent            |
| Tests marketing | `bun run --filter=@via/marketing test`                                                                                        | tous passent                    |
| Typecheck       | `bun run --filter=@via/marketing typecheck`                                                                                   | exit 0                          |
| Lint            | `bun run --filter=@via/marketing lint`                                                                                        | exit 0                          |
| Build           | `bun run --filter=@via/marketing build`                                                                                       | exit 0                          |
| Liens inertes   | `if rg -n 'href:\s*"#"' apps/marketing/src/constants/page.ts apps/marketing/src/constants/analytics-page.ts; then exit 1; fi` | exit 0, aucun `href: "#"` exact |

## Périmètre

### Fichiers autorisés

- `apps/marketing/src/constants/launch.ts` (nouveau)
- `apps/marketing/src/constants/launch.test.ts` (nouveau)
- `apps/marketing/src/constants/page.ts`
- `apps/marketing/src/constants/analytics-page.ts`
- `apps/marketing/src/constants/navigation.ts`
- `apps/marketing/src/components/ui/launch-action.tsx` (nouveau)
- `apps/marketing/src/components/ui/app-store-badge-link.tsx` uniquement si son type doit être exporté/réutilisé
- `apps/marketing/src/components/sections/hero/hero-copy.tsx`
- `apps/marketing/src/components/sections/analytics/analytics-hero.tsx`
- `apps/marketing/src/components/sections/analytics/analytics-download-section.tsx`
- `apps/marketing/src/components/layout/download-card.tsx`
- `apps/marketing/src/components/sections/faq/faq-section.tsx`
- `apps/marketing/src/app/trip/[token]/page.client.tsx`
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- La soumission App Store, TestFlight, les métadonnées ASC et le script de déploiement.
- La création d’une liste d’attente, d’une newsletter ou d’un formulaire de contact.
- Les pages `/api` et `/integrations`, traitées par le plan 017.
- Les autres ancres locales légitimes telles que `#download`, `#sources` ou `#categories`.
- Le deep link `via://trip/…` et la logique du trajet partagé.
- Toute collecte analytique ou nouveau cookie autour des CTA.

## Git

- Branche recommandée : `codex/011-centralize-launch-destinations`.
- Commits logiques, par exemple
  `fix(marketing): make launch calls to action truthful`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Établir le statut réel avant d’écrire une URL

Demander à l’opérateur de confirmer l’un des deux états au moment de
l’exécution :

- `prelaunch` — la fiche publique n’est pas encore disponible ;
- `available` — la fiche française est effectivement accessible au public.

Le document du dépôt daté du 25 août constitue une preuve pour `prelaunch`, pas
une preuve permanente. Si l’opérateur choisit `available`, il doit fournir ou
valider l’URL canonique. Pour l’App ID connu, la forme attendue est
`https://apps.apple.com/fr/app/metyro/id6801259695`; la requête publique doit
répondre sans redirection vers une erreur ou une autre app. Si un lien TestFlight
public est souhaité, il doit lui aussi être fourni explicitement par
l’opérateur.

Valider séparément la destination assistance. En l’absence d’une adresse ou
d’un outil approuvé, utiliser `/help`, déjà routé et cohérent avec les
métadonnées de support actuelles.

**Vérifier** : consigner dans la PR soit `phase=prelaunch`, soit
`phase=available`, puis la preuve utilisée et `support=/help` (ou la destination
explicitement approuvée). Si ces trois informations ne peuvent pas être
établies, STOP.

### 2. Définir un modèle de lancement discriminé et unique

Créer `constants/launch.ts` avec un type explicite qui interdit les états
hybrides :

```ts
type LaunchConfiguration =
  | {
      readonly phase: "prelaunch";
      readonly availabilityLabel: string;
      readonly appStoreAction: null;
    }
  | {
      readonly phase: "available";
      readonly availabilityLabel: string;
      readonly appStoreAction: CallToAction;
    };
```

Exporter :

- `launch`, configuré avec l’état confirmé à l’étape 1 ;
- `supportAction`, une seule action avec libellé et destination réels ;
- un modèle dérivé pour la navigation vers `#download`, dont le libellé vaut
  « Disponibilité » en pré-lancement et « Télécharger » une fois publiée ;
- un petit type `LaunchActionContent` si nécessaire aux composants, sans
  recopier l’URL ni le statut.

Pour `prelaunch`, utiliser un libellé non ambigu tel que « Bientôt disponible
sur l’App Store » et `appStoreAction: null`. Pour `available`, utiliser
« Disponible maintenant » et l’URL canonique approuvée. Ne lire aucune variable
d’environnement côté client pour décider du statut : une build doit produire
un message déterministe et relu.

**Vérifier** : `bun run --filter=@via/marketing typecheck` → exit 0.

### 3. Rendre l’état avec un composant partagé, jamais avec un faux lien

Créer `components/ui/launch-action.tsx`. Il reçoit la configuration centrale et
un mode visuel étroit (`badge` pour les emplacements Apple, `button` pour le
footer/FAQ, ainsi que l’apparence claire ou sombre nécessaire).

- En phase `available`, déléguer au `AppStoreBadgeLink` existant en mode badge,
  ou à la présentation d’action existante en mode bouton, toujours avec la même
  URL centrale.
- En phase `prelaunch`, rendre un élément non interactif (`p` ou `span`) portant
  le statut. Il ne doit avoir ni `href`, ni rôle button/link, ni animation de
  pression. Le texte doit rester lisible et garder une hauteur visuelle proche
  afin de ne pas casser la composition.
- Le composant ne décide pas du statut, ne lit pas `window` et ne duplique aucun
  libellé.

Conserver les styles focus et la cible du badge lorsqu’il est réellement
cliquable. Ne changer ni les assets Apple ni leurs dimensions.

**Vérifier** : `bun run --filter=@via/marketing typecheck` puis
`bun run --filter=@via/marketing lint` → deux exits 0.

### 4. Remplacer toutes les copies par la source unique

Dans `page.ts` et `analytics-page.ts`, supprimer les deux constantes locales
`appStoreAction`. Réutiliser `launch`, le contenu d’action central et
`supportAction`. Le badge du hero doit provenir de
`launch.availabilityLabel`; il ne peut plus rester codé à « Disponible
maintenant » pendant un pré-lancement.

Remplacer les rendus suivants par `LaunchAction` :

1. `HeroCopy` ;
2. `AnalyticsHero` ;
3. `AnalyticsDownloadSection` ;
4. `DownloadCard` ;
5. l’action de disponibilité dans `FAQSection` ;
6. le badge de `JourneySharePageClient`.

Dans la page de trajet partagé, garder le bouton « Ouvrir dans l’app ». Le
second élément devient le statut pré-lancement ou la vraie fiche App Store selon
la configuration ; il ne pointe plus vers `/#download` pour masquer l’absence
d’URL.

Dans `navigation.ts`, dériver le libellé du lien `#download` de la configuration
centrale. Cette ancre interne reste valide : elle conduit à la section qui
explique honnêtement la disponibilité.

**Vérifier** :

```bash
if rg -n 'const appStoreAction|href:\s*"#"|href="/#download"' \
  apps/marketing/src/constants/page.ts \
  apps/marketing/src/constants/analytics-page.ts \
  apps/marketing/src/app/trip/'[token]'/page.client.tsx; then exit 1; fi
```

Résultat attendu : exit 0, aucune copie ni destination inerte.

### 5. Ajouter les tests de cohérence du lancement

Créer `constants/launch.test.ts` avec `bun:test`. Tester les deux branches via
une fonction pure de validation ou de dérivation, même si une seule est active
dans la configuration exportée :

- `prelaunch` produit `appStoreAction: null`, un statut non vide et un libellé
  de navigation qui ne promet pas un téléchargement ;
- `available` refuse une URL non HTTPS, un hôte autre que `apps.apple.com`, un
  identifiant autre que `6801259695` et accepte l’URL canonique approuvée ;
- `supportAction.href` n’est ni vide ni `#` et vaut la destination approuvée ;
- l’action de navigation pointe vers `#download`, qui existe toujours dans
  `DownloadCard` ;
- `pageContent` et `analyticsContent` consomment le même modèle exporté plutôt
  que deux copies égales par hasard.

Si le modèle reste une simple constante sans fonction de validation, tester le
résultat exporté et ajouter un contrôle source ciblé pour les copies ; ne pas
introduire Zod uniquement pour ce fichier.

**Vérifier** : `bun test apps/marketing/src/constants/launch.test.ts` → tous les
tests passent.

### 6. Valider chaque surface de production

Exécuter la suite et le build. Inspecter les sorties rendues de `/`,
`/analytics`, `/help` et d’une route `/trip/` construite avec un token de test
valide dans l’état choisi :

- aucun contrôle App Store inerte ;
- statut pré-lancement visible mais non focusable, ou vraie fiche accessible ;
- lien assistance vers la destination approuvée ;
- navigation « Disponibilité »/« Télécharger » cohérente avec le footer ;
- deep link du trajet conservé.

**Vérifier** :

```bash
bun run --filter=@via/marketing test
bun run --filter=@via/marketing typecheck
bun run --filter=@via/marketing lint
bun run --filter=@via/marketing build
```

Résultat attendu : quatre exits 0.

## Plan de test

- Nouveau `constants/launch.test.ts` : branches `prelaunch`/`available`, URL
  Apple, App ID, assistance et cohérence navigation.
- Contrôle source ciblé : aucune destination exacte `#` dans les constantes et
  aucune redirection App Store vers `/#download` dans le trajet partagé.
- Tests existants marketing : aucune régression des helpers et pages.
- Build Next : compilation des usages serveur/client du modèle discriminé.
- Vérification manuelle clavier : en pré-lancement, le statut n’entre pas dans
  l’ordre de tabulation ; une fois disponible, le badge reçoit le focus et ouvre
  la bonne fiche.

## Critères de fin

- [ ] Une seule configuration exporte phase, statut, App Store et assistance.
- [ ] La phase active a été confirmée par l’opérateur et sa preuve est consignée.
- [ ] Aucun `href: "#"` exact ne subsiste pour le téléchargement ou l’assistance.
- [ ] En pré-lancement, aucun faux contrôle App Store n’est rendu.
- [ ] En disponibilité, chaque badge utilise la même URL HTTPS et le bon App ID.
- [ ] Le hero, l’analytics, la FAQ, le footer, la navigation et le trajet partagé sont cohérents.
- [ ] Les tests du modèle couvrent les deux phases et passent.
- [ ] Tests, typecheck, lint et build marketing sortent 0.
- [ ] Aucun fichier hors périmètre n’est modifié, hormis le statut dans `plans/README.md`.

## Conditions STOP

Arrêter et remonter le problème si :

- l’opérateur ne peut pas confirmer si l’app est encore en pré-lancement ou
  réellement publique ;
- une phase `available` est demandée mais aucune fiche publique valide ne peut
  être ouverte et rattachée à l’App ID `6801259695` ;
- un lien TestFlight ou une destination d’assistance externe est souhaité mais
  son URL n’est pas fournie et approuvée ;
- la solution exige une liste d’attente, un formulaire ou une collecte de
  données non spécifiés ;
- une surface de CTA non listée porte une troisième politique de lancement et
  ne peut pas adopter la configuration sans élargir le périmètre ;
- un test/build échoue deux fois après correction raisonnable ;
- un fichier hors périmètre doit être modifié.

## Notes de maintenance

- Le jour de la publication, un seul changement de configuration doit faire
  basculer toutes les surfaces. La review doit refuser toute nouvelle URL App
  Store locale dans un composant ou un fichier de contenu.
- L’identifiant Apple est public, mais l’état de publication doit toujours être
  vérifié ; App Store Connect et la fiche publique ne sont pas équivalents.
- Si un vrai canal de support apparaît, changer `supportAction` et ajouter son
  test, sans réintroduire une copie dans la FAQ.
- Le plan 017 modifie aussi `navigation.ts` pour retirer les promesses d’API
  publique. Exécuter 011 avant 017 pour éviter de perdre la dérivation du libellé
  de lancement lors de la résolution du même fichier.
