# Prompt — Landing page Via (Next.js + Motion, worktree)

Tu construis la landing page publique de l'app iOS de ce monorepo. Travaille de bout en bout, sans me demander de valider chaque étape. Trois questions seulement avant de commencer (§0), puis tu exécutes.

## 0. Avant d'écrire une ligne

Pose-moi ces trois questions, et **uniquement** celles-là :
1. Nom de marque à afficher : `Via` ou `Metyro` ? (le repo dit `PRODUCT_NAME = via`)
2. Le lien App Store / TestFlight derrière le CTA (ou `#` en attendant)
3. Domaine de prod pour les métadonnées OG (ou `http://localhost:3000` en attendant)

Tout le reste, tu le décides toi-même avec les règles ci-dessous. Ne me redemande pas la structure, les couleurs, la copy, les durées d'animation.

## 1. Setup — worktree

Depuis la racine du repo :

```bash
git worktree add ../via-landing -b feat/landing-page
cd ../via-landing
```

Tout le travail se fait dans ce worktree. Ne touche à rien dans `apps/via`, `apps/api`, `packages/`.

## 2. Les skills sont déjà installées — utilise-les

Elles sont dans `~/.claude/skills/`, disponibles depuis n'importe quel worktree. **Tu les lis avant de coder, pas après.**

| Skill | Quand |
| --- | --- |
| `apple-design` | **Avant le premier composant.** Fondations : matériaux translucides, profondeur, typographie (tracking dépendant de la taille, optical sizing), springs, interruptibilité, reduced-motion. |
| `animate` (+ `RECIPES.md`) | **Avant la première animation.** Séquence de décision obligatoire : est-ce que ça doit animer → quel but → quel outil → quelles propriétés → quelle courbe. Les tables de courbes et de durées sont normatives. |
| `emil-design-engineering` | Détail d'implémentation : focus states, tap targets, font rendering, layout shift. Son `marketing.md` couvre précisément les pages de ce type. |
| `animation-vocabulary` | Si tu hésites sur le nom d'un effet. |
| `pick-ui-library` | **Invocation explicite** (`Skill(pick-ui-library)`). Uniquement si tu as besoin d'un *composant* (accordéon FAQ, dialog) plutôt que d'une animation. Ne hand-roll pas un accordéon. |
| `review-animations` | **Invocation explicite** (`Skill(review-animations)`), à la fin, sur ton propre diff. Tu corriges tout ce qu'elle flag avant de me rendre la main. |

Règle de préséance : `animate` gouverne les courbes, durées et le choix d'outil. `apple-design` gouverne la sensation générale, les matériaux et la typographie. En cas de conflit sur une valeur numérique, `animate` gagne.

## 3. Le produit (contexte factuel, ne l'invente pas)

App iOS 26 native, SwiftUI, transports en commun à Paris (métro, RER, bus). Ce qu'elle fait, vérifiable dans `apps/landing/public/images/` :

- **`ai-search.png`** — « Recherche intelligente » : tu décris ton trajet en une phrase (« Gare du Nord vers Orly, sans RER ») et l'app comprend lieux, heure, contraintes. Mention en bas de l'écran : « Traité sur cet iPhone avec Apple Intelligence » — **c'est l'argument différenciant : le traitement est local, rien ne part sur un serveur.**
- **`live-activity.png`** — trajet en cours : « Descendre dans 3 arrêts », progression sur la ligne, correspondances, marche finale, heure d'arrivée.
- **`disruptions.png`** — perturbations en temps réel.
- **`stations-map.png`** — carte des stations.
- **`preferences.png`** — préférences de trajet.

Ces cinq PNG sont **déjà dans le repo** (~1206×2622, screenshots réels, UI française). Tu les utilises comme visuels produit. **Tu n'inventes aucune fonctionnalité, aucun chiffre, aucun témoignage, aucun logo de presse.**

## 4. Référence

Structure narrative : https://getwagon.fr/ — nav minimale, un hero, puis des sections thématiques montrant le produit avec de vrais screenshots et une copy courte. Tu t'en inspires pour le **rythme**, pas pour le pixel. Le rendu visuel doit être Apple : blanc, typographie énorme et serrée, beaucoup de vide, une seule couleur d'accent.

## 5. Stack et structure

- Next.js (App Router, dernière stable), TypeScript strict, Tailwind v4, shadcn/ui, **Motion** (`bun add motion`, imports depuis `motion/react`), Bun.
- Le projet complète `apps/landing` : `package.json` nommé `@via/landing`, scripts `dev` / `build` / `typecheck` pour que Turbo le prenne (`turbo.json` a déjà les tasks `dev` et `typecheck`).
- `bunx --bun shadcn@latest init`, puis n'ajoute que les composants réellement utilisés.

Arborescence attendue :

```
apps/landing/
  src/
    app/
      layout.tsx                  # fonts, <html lang="fr">, thème
      globals.css                 # tokens Tailwind v4 (@theme) + tokens d'easing
      (marketing)/
        layout.tsx                # nav + footer publics
        page.tsx                  # SERVER : metadata, JSON-LD, compose
        page.client.tsx           # "use client" : orchestration Motion
        _components/
          site-header.tsx
          hero.tsx
          hero.client.tsx
          reveal.client.tsx       # primitive de reveal partagée
          feature-*.tsx
          faq.tsx
          site-footer.tsx
      (auth)/
        layout.tsx
        sign-in/page.tsx + page.client.tsx + _components/
        sign-up/page.tsx + page.client.tsx + _components/
      (app)/
        layout.tsx
        dashboard/page.tsx + page.client.tsx + _components/
    components/ui/                # shadcn
    lib/
      motion.ts                   # transitions partagées, typées
      utils.ts
  public/images/                  # les 5 screenshots existants
```

Conventions **non négociables** :

- `page.tsx` = Server Component. Il exporte `metadata`, fait le fetch s'il y en a un, rend `<PageClient />` avec des props sérialisables. **Jamais** de `"use client"` dedans.
- `page.client.tsx` = `"use client"`, reçoit ses données en props, ne fetch pas.
- `_components/` colocalisé par page. Un composant est Server par défaut ; s'il est interactif ou animé il porte le suffixe `.client.tsx` et son propre `"use client"`. La frontière client est poussée **le plus bas possible** — un `<motion.div>` dans une section ne rend pas la section entière cliente, tu isoles le wrapper animé.
- Un fichier = un composant exporté, nommé comme le fichier.

`(marketing)` est **livré fini**. `(auth)` et `(app)` sont des coquilles propres et visuellement cohérentes (layout + un écran statique chacun), sans logique d'authentification, sans dépendance ajoutée.

## 6. Le hero — un seul, spécifié

Un hero, pas deux, pas de carousel, pas de vidéo autoplay. Dans cet ordre :

1. Nav fine et translucide (`backdrop-filter: blur(20px) saturate(180%)` + fond semi-opaque), logo à gauche, un ou deux liens, CTA à droite. Le contenu passe **dessous** au scroll — ce n'est pas une barre opaque posée sur la page.
2. `<h1>` en français, 6 à 10 mots, `clamp()`, `line-height: 1.03`, `letter-spacing: -0.03em`, poids 600–700. Il dit ce que fait l'app, pas ce qu'elle « révolutionne ».
3. Une phrase de sous-titre. Une. Grise, ~1.25rem, `letter-spacing: 0`.
4. CTA App Store (bouton plein, accent) + un lien secondaire discret. Sous les boutons, une ligne fine : « Disponible sur iOS 26 ».
5. Le visuel produit : `live-activity.png` ou `ai-search.png` dans un cadre d'iPhone dessiné en CSS (bezel sombre, `border-radius` ~54px, ombre large et diffuse, aucune image de mockup importée).

Pas de blob flouté, pas de grille en fond, pas de badge au-dessus du titre annonçant une nouveauté imaginaire.

## 7. Après le hero

Quatre à cinq sections, chacune un `<h2>` court et une idée unique :

1. **La recherche en langage naturel** — la phrase tapée, ce que l'app en comprend. `ai-search.png`, grand. C'est la section la plus travaillée de la page.
2. **Le traitement local** — Apple Intelligence sur l'appareil, rien ne part. Sobre, typographique, peu ou pas d'image. Ça se lit comme une phrase, pas comme une feature-card.
3. **Le trajet en cours** — `live-activity.png`.
4. **Perturbations + carte + préférences** — les trois derniers screenshots, rythme alterné texte/image, pas une grille de cartes.
5. **CTA final** — le bouton App Store, une phrase, rien d'autre.

Puis un footer réel : nom, année, liens légaux (placeholders honnêtes), rien de plus.

## 8. Direction artistique — ce qui est interdit

Le point le plus important du brief. La page ne doit pas ressembler à une landing générée. Sont **bannis** :

- les dégradés violet/indigo/cyan, en fond comme en `bg-clip-text` ;
- les orbes lumineux, blobs floutés, halos, `radial-gradient` décoratifs, grilles en fond ;
- les badges « ✨ Powered by AI », « New », « v2.0 » ;
- les grilles de trois cartes à icône Lucide + titre + deux lignes ;
- les emojis dans la copy ou les puces ;
- le hero sombre néon ;
- les chiffres inventés, faux témoignages, faux logos « ils parlent de nous » ;
- le look shadcn par défaut : `rounded-lg` partout, `border-border` visible sur chaque bloc, `bg-muted` en fond de section. shadcn est une base accessible, tu **redéfinis les tokens** ;
- le bento grid quand il n'y a rien à mettre dedans ;
- `text-gray-500` sur tout ce qui n'est pas un titre ;
- le scroll-jacking, le parallaxe lourd, les animations qui retardent la lecture.

Sont **attendus** :

- fond blanc ou blanc cassé (`#fff` / `#fbfbfd`), texte quasi noir (`#1d1d1f`), un seul gris de support ;
- **une seule** couleur d'accent, prélevée dans le produit — le magenta du bouton « Rechercher » de `ai-search.png`. Échantillonne-le, ne l'invente pas. Il sert au CTA, et à presque rien d'autre ;
- une échelle typographique franche : titres très grands, body normal, pas de tailles intermédiaires molles. Tracking négatif au-dessus de 32px, neutre en dessous ;
- du vide généreux et **irrégulier** : les sections respirent différemment selon leur poids, elles n'ont pas toutes le même `py-24` ;
- rayons de coin cohérents et grands (16–24px), ombres larges et très diffuses, jamais de `box-shadow` dure ;
- des séparations par changement de fond ou par vide, pas par `border-t` ;
- `-apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui` en priorité, avec `font-optical-sizing: auto`. Si webfont : Inter Display **seule**, jamais deux familles.

## 9. Copy

Français, **tutoiement** (l'app dit « Décris ton trajet »), cohérent partout. Phrases courtes, verbes concrets, présent. Zéro superlatif, zéro point d'exclamation, zéro « révolutionnaire / seamless / effortless / game-changer ». Un `<h2>` fait moins de 8 mots. Un paragraphe fait 1 à 2 phrases. Si une phrase peut sauter, elle saute.

## 10. Mouvement — Motion, avec discipline

**Motion (`motion.dev`) est la bibliothèque d'animation du projet.** Tu l'installes et tu construis le système de mouvement avec. Mais tu passes d'abord par la séquence de décision de la skill `animate` : Motion est l'outil pour les springs, les reveals au scroll, les entrées/sorties et le gesture-driven — **pas** pour ce qu'une transition CSS fait mieux.

**Répartition imposée :**

| Cas | Outil |
| --- | --- |
| Press d'un bouton (`:active`, `scale(0.97)`), hover, changement de couleur | **CSS transition** — pas de JS |
| Reveal des sections au scroll | **Motion** (`whileInView`) |
| Entrée du hero au chargement | **Motion** (spring) |
| Ouverture/fermeture (FAQ, menu mobile) | **Motion** + `AnimatePresence` |

**Règles Motion non négociables :**

- **String transform complète, jamais les raccourcis.** `animate={{ transform: "translateY(0px)" }}`, **pas** `animate={{ y: 0 }}` — les raccourcis `x`/`y`/`scale` ne sont pas accélérés matériellement et perdent des frames sous charge.
- `transform` et `opacity` uniquement. Jamais `width`, `height`, `top`, `margin`.
- **Jamais `scale(0)`.** Une entrée part de `scale(0.96)` + `opacity: 0`.
- Reveals au scroll : `whileInView` avec `viewport={{ once: true, margin: "-15% 0px" }}`. Une seule fois. Jamais de re-trigger au scroll inverse.
- Amplitude d'un reveal : `translateY(12px)` → `0`, `opacity 0 → 1`. Rien de plus. Un reveal qui se remarque est un reveal raté.
- Stagger : `delayChildren` / `staggerChildren` autour de `0.06s`. Au-delà de 4 enfants, pas de stagger — ça devient une file d'attente.
- **Springs** (hero, éléments qui répondent à un geste) : API `{ type: "spring", bounce: 0, duration: 0.4 }`. `bounce: 0` par défaut (équivalent damping 1.0) ; `bounce: 0.2` **uniquement** si un geste a porté de l'élan. Jamais de rebond décoratif sur une entrée au scroll.
- **Tweens** : courbes issues de la skill `animate`, définies une fois en tokens dans `globals.css` et réutilisées côté Motion depuis `lib/motion.ts` :
  ```css
  --ease-out: cubic-bezier(0.23, 1, 0.32, 1);
  --ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);
  ```
  `ease-out` pour tout ce qui entre ou sort. **`ease-in` sur de l'UI est interdit.** Les easings CSS natifs (`ease`, `ease-out`) sont trop faibles, tu ne les utilises pas tels quels.
- Durées : sous 300ms pour tout élément d'UI. Un reveal de section marketing peut aller à 400–500ms, c'est le seul endroit où c'est justifié — et tu le justifies.
- **Reduced motion** : `useReducedMotion()` de `motion/react`, branché dans `lib/motion.ts` pour que **toutes** les transitions du projet le respectent d'un seul endroit. En reduced motion : cross-fade opacity seul, aucun déplacement, aucun spring.
- Pas de `layout` / `layoutId` sur cette page — il n'y a pas d'élément partagé entre deux états. Si tu en ajoutes un, justifie-le.
- Pas d'animation sur du texte que l'utilisateur est en train de lire. Pas de mot-à-mot, pas de machine à écrire, pas de compteur qui s'incrémente.
- Feedback au `pointerdown`, jamais au `click`.

**Budget global : la page doit rester lisible avec JavaScript lent.** Le contenu est dans le DOM et visible sans attendre Motion — les reveals partent d'un état déjà lisible ou sont gérés pour ne pas laisser une section blanche si l'hydratation traîne.

## 11. Qualité — critères d'acceptation

- `bun run typecheck` et `bun run build` passent, zéro `any`, zéro warning React.
- HTML sémantique : un seul `<h1>`, hiérarchie correcte, `<main>`, `<nav>`, `<footer>`.
- Toutes les images en `next/image` avec `width`/`height` réels et `alt` descriptif en français. **Zéro CLS.**
- Contraste AA minimum. Focus visible au clavier sur chaque élément interactif. Cibles tactiles ≥ 44px.
- Métadonnées complètes : title, description, `openGraph`, `twitter`, `lang="fr"`, favicon.
- Responsive vérifié à 390px, 768px, 1440px — la typographie du hero reste **tenue** à 390px, pas juste rétrécie.
- Aucune animation ne tourne en boucle. Aucune n'empêche de scroller.

## 12. Vérification avant de me rendre la main

1. `bun run build`, puis `bun run dev`.
2. Ouvre la page dans Chrome, screenshots à **1440×900** et **390×844**, scroll complet.
3. Regarde tes propres captures et corrige : veuves typographiques, espacements incohérents, alignements flottants, contraste faible.
4. **Invoque `Skill(review-animations)` sur ton diff.** Elle flague par défaut, l'approbation se mérite. Tu corriges chaque finding avant de me répondre — tu ne me transmets pas une liste de problèmes connus.
5. Rends-moi : chemin du worktree, commande de lancement, screenshots, et en 5 lignes tes décisions de direction artistique (accent prélevé, échelle typo, rythme des sections) + le verdict de `review-animations` après corrections.

Pas de commit tant que je n'ai pas vu les captures.
