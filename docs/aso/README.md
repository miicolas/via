# ASO — Metyro

Travail d'App Store Optimization pour Metyro (App Store FR), conduit avec les compétences
[ASO Skills](https://github.com/eronred/aso-skills) et le pack de compétences `asc`
(App Store Connect CLI).

## Documents

| Fichier | Contenu |
|---|---|
| [`../../app-marketing-context.md`](../../app-marketing-context.md) | Contexte marketing — positionnement, concurrents, contraintes. Toutes les compétences ASO le lisent en premier |
| [`01-audit.md`](01-audit.md) | Audit ASO complet : score, contrôles hors-ligne, plan d'action priorisé |
| [`02-keyword-research.md`](02-keyword-research.md) | Recherche de mots-clés FR, méthode, arbitrage sur les marques tierces |
| [`03-metadata.md`](03-metadata.md) | Champs optimisés, 3 options par champ, matrice de couverture, commandes de mise en ligne |
| [`data/`](data/) | Données brutes horodatées (25/08/2026) : autocomplétion Apple FR, SERP, métadonnées concurrentes |

Les valeurs recommandées sont appliquées dans `apps/via/metadata/`, validées par
`asc metadata validate`, et **pas encore poussées** sur App Store Connect.

## Le chemin le plus court

1. Poser les métadonnées (`03-metadata.md` § « Poser les changements »).
2. Produire les captures — bloquant pour la soumission et 15 % du score ASO.
3. Débloquer la soumission : build, coordonnées de review, App Privacy, catégories.
4. Après publication : relever les classements réels, ils remplaceront les proxys de `02`.

## Rejouer le travail

```bash
# Récupérer l'état réel de la fiche
asc metadata pull --app 6801259695 --version 1.0 --platform IOS --dir ./apps/via/metadata --force

# Readiness de soumission
asc validate --app 6801259695 --version 1.0
```

Puis les compétences, dans cet ordre : `aso-audit` → `keyword-research` →
`metadata-optimization`. `screenshot-optimization` pour les captures,
`localization` avant toute ouverture de marché, `review-management` après publication.

À rejouer **tous les mois** — l'ASO n'est pas une opération ponctuelle. La recherche de
mots-clés, tous les trimestres : les requêtes transport bougent avec les grèves, les
travaux, les extensions de ligne et les saisons.

## Compétences installées

**ASO Skills** (`.agents/skills/`, symlinkées dans `.claude/skills/`) — `aso-audit`,
`keyword-research`, `metadata-optimization`, `competitor-analysis`,
`screenshot-optimization`, `localization`, `review-management`, `custom-product-pages`,
`ab-test-store-listing`, `asc-metrics`, `app-marketing-context`.

**Pack asc** (`~/.agents/skills/`, global, installé par `asc install-skills`) —
23 compétences dont `asc-aso-audit`, `asc-metadata-sync`, `asc-shots-pipeline`,
`asc-screenshot-resize`, `asc-localize-metadata`, `asc-submission-health`,
`asc-release-flow`, `asc-whats-new-writer`.
