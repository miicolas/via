# Plans d’implémentation

Le plan 001 a été généré avec le skill `improve` le 2026-08-19. Les plans
002 à 020 ont été générés le 2026-08-29 au commit `a58e6a12` après un audit du
monorepo. Exécuter les plans dans l’ordre ci-dessous, respecter leurs conditions
STOP et mettre à jour leur statut à la fin de l’exécution.

## Ordre et statut

| Plan                                                    | Titre                                                                           | Priorité | Effort | Dépend de | Statut |
| ------------------------------------------------------- | ------------------------------------------------------------------------------- | -------- | ------ | --------- | ------ |
| [001](001-redesign-line-detail-service-map.md)          | Rendre le plan de ligne et ses travaux immédiatement lisibles                   | P1       | M      | —         | DONE   |
| [002](002-restaurer-baseline-tests-ios.md)              | Restaurer une baseline iOS complète et la rendre bloquante                      | P1       | M      | —         | DONE   |
| [003](003-supprimer-donnees-privees-des-journaux.md)    | Ne jamais journaliser les recherches ni les coordonnées privées                 | P1       | M      | —         | DONE   |
| [004](004-fiabiliser-identite-ip-railway.md)            | Fonder les quotas anonymes sur l’adresse injectée par Railway                   | P1       | S      | —         | DONE   |
| [005](005-isoler-mutations-session-authentification.md) | Isoler chaque mutation d’authentification par génération de session             | P1       | M      | 002       | DONE   |
| [006](006-effacer-tous-espaces-comptes-locaux.md)       | Effacer tous les espaces de compte persistés sur l’appareil                     | P1       | S      | 002       | DONE   |
| [007](007-borner-payloads-trajets.md)                   | Borner les corps HTTP et les graphes de trajet renvoyés par les clients         | P1       | M      | 003       | DONE   |
| [008](008-upgrade-nextjs-security.md)                   | Mettre Next.js à niveau vers une version corrigée de l’App Router               | P1       | M      | —         | DONE   |
| [009](009-secure-gtfs-archive-extraction.md)            | Confiner l’extraction des archives GTFS dans leur répertoire temporaire         | P1       | M      | 008       | DONE   |
| [010](010-rendre-version-cache-transport-durable.md)    | Rendre durable la version du cache après un import GTFS                         | P1       | M      | 007       | DONE   |
| [011](011-centralize-launch-destinations.md)            | Rendre chaque appel au lancement vrai depuis une configuration unique           | P1       | M      | —         | DONE   |
| [012](012-rendre-compteurs-redis-atomiques.md)          | Rendre atomiques l’incrément et l’expiration des compteurs Redis                | P1       | S      | —         | DONE   |
| [013](013-reapprovisionner-rappels-locaux.md)           | Réapprovisionner les rappels locaux hors de l’écran Réglages                    | P1       | M      | 002       | DONE   |
| [014](014-terminer-trajet-avant-nettoyage-async.md)     | Terminer localement le trajet avant son nettoyage asynchrone                    | P1       | M      | 002       | DONE   |
| [015](015-expirer-coordonnees-localisation.md)          | Expirer les coordonnées de localisation avant recherche et planification        | P1       | M      | 002       | DONE   |
| [016](016-borner-cycle-vie-partages-trajets.md)         | Borner la rétention et la projection publique des trajets partagés              | P1       | M      | —         | DONE   |
| [017](017-align-first-party-api-messaging.md)           | Aligner le site et le README sur une API strictement première partie            | P2       | M      | 011       | DONE   |
| [018](018-track-railway-runtime-dependencies.md)        | Déclencher Railway sur toute dépendance qui change le service construit         | P2       | S      | —         | DONE   |
| [019](019-bound-journey-share-fetches.md)               | Borner chaque lecture de trajet partagé et conserver un état indisponible       | P2       | S      | 016       | DONE   |
| [020](020-declare-french-site-locale.md)                | Déclarer le français dans le document HTML et toutes les métadonnées Open Graph | P2       | S      | —         | DONE   |

Valeurs de statut : `TODO`, `IN PROGRESS`, `DONE`, `BLOCKED` (avec raison) ou
`REJECTED` (avec justification).

## Dépendances

- Les plans 005, 006, 013, 014 et 015 attendent le plan 002 afin que leur
  non-régression iOS complète compile et soit réellement bloquante.
- Le plan 007 suit 003 : tous deux modifient l’ordre des middlewares dans
  `apps/api/src/app.ts`, et la limite de corps doit conserver le logger sûr.
- Le plan 010 suit 007 — et donc transitivement 003 — pour préserver cet ordre
  lorsqu’il adapte la lecture de version réseau dans `app.ts`.
- Le plan 009 suit 008 parce que les deux modifient `bun.lock`.
- Le plan 017 suit 011 parce que les deux modifient
  `apps/marketing/src/constants/navigation.ts`.
- Le plan 019 suit 016 parce que les deux modifient
  `apps/marketing/src/lib/journey-share.ts`; le timeout doit conserver le
  contrat public strict créé par 016.

## Baseline au commit de planification

- `bun run typecheck`, `bun run test` et `bun run check:openapi` étaient verts.
- La suite iOS complète s’arrêtait avant exécution sur les assertions obsolètes
  de `NetworkRemoteModelsTests.swift`; le plan 002 restaure ce gate avant les
  autres changements iOS.
- Le worktree contenait déjà des ajouts utilisateur autour des tarifs et des
  fontaines. Chaque plan concerné les nomme explicitement et interdit de les
  restaurer ou de les écraser.

## Pistes considérées et écartées

- **Ajouter une carte géographique MapKit au plan 001** : hors périmètre, car
  le détail de ligne ne fournit pas la géométrie nécessaire et le problème
  signalé porte d’abord sur la lisibilité du schéma et des travaux.
- **Sélectionner un travail pour filtrer le tracé du plan 001** : interaction
  intéressante mais trop large pour cette refonte ; elle nécessite un état et
  une projection des identifiants de perturbation dans le layout.
- **Traiter la clé client iOS comme un secret inextractible, fermer `/api/health`
  ou supprimer le fail-open de configuration** : ces compromis sont explicitement
  acceptés par l’ADR 0003. Les plans 003, 004, 007 et 012 renforcent les vraies
  frontières de confidentialité et de quota sans contredire cette décision.
- **Mélanger le contrôle Prettier marketing aux 19 correctifs** : la dérive de
  format globale est préexistante et cosmétique ; elle mérite un nettoyage
  mécanique séparé plutôt qu’un élargissement silencieux de chaque plan.
