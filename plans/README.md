# Plans d’implémentation

Générés avec le skill `improve` le 2026-08-19. Exécuter les plans dans l’ordre
ci-dessous, respecter leurs conditions STOP et mettre à jour leur statut à la
fin de l’exécution.

## Ordre et statut

| Plan | Titre | Priorité | Effort | Dépend de | Statut |
| --- | --- | --- | --- | --- | --- |
| 001 | Rendre le plan de ligne et ses travaux immédiatement lisibles | P1 | M | — | DONE |

Valeurs de statut : `TODO`, `IN PROGRESS`, `DONE`, `BLOCKED` (avec raison) ou
`REJECTED` (avec justification).

## Dépendances

- Aucune. Le plan 001 conserve les modèles, le repository et les règles de
  projection existantes.

## Pistes considérées et écartées

- **Ajouter une carte géographique MapKit** : hors périmètre, car le détail de
  ligne ne fournit pas la géométrie nécessaire et le problème signalé porte
  d’abord sur la lisibilité du schéma et des travaux.
- **Sélectionner un travail pour filtrer le tracé** : interaction intéressante
  mais trop large pour cette refonte de positionnement ; elle nécessite un état
  et une projection des identifiants de perturbation dans le layout.
