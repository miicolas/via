# Incident — « Aucun itinéraire en transport » depuis la banlieue

**Date** : 27 août 2026 · **Statut** : cause racine corrigée, release v0.2.35 à vérifier sur Railway · **Sévérité** : majeure (fonctionnalité cœur inutilisable depuis l'ouest parisien)

---

## 1. Symptôme

Une recherche depuis une adresse de banlieue — notamment le favori « Maison » à Carrières-sous-Poissy vers 15 rue Vivienne, ou « Alicia » vers Chatou/La Défense — affichait **« Aucun itinéraire en transport »** alors que le trajet existe. Les tuiles à pied et à vélo restaient présentes.

- Depuis une station parisienne épinglée comme Auber : des résultats.
- Depuis une adresse à l'ouest de Paris : aucun trajet dès que les alternatives utilisaient le RER A.
- La réponse HTTP restait `200`, `status: no-route`, `source: idfm-realtime`.

## 2. Reproduction décisive

Le diagnostic initial accusait un backend PRIM désynchronisé. Il était faux : `source: idfm-realtime` nomme l'origine du plan avant enrichissements, pas la frontière qui l'a vidé.

La même demande, au même instant, a été rejouée à chaque frontière :

| Frontière | Résultat |
|---|---|
| API Via sur Railway, cache contourné par un ID d'adresse unique | **0 trajet** (`no-route`) |
| URL `journeyUrl()` byte-exacte appelée directement sur PRIM | **4 trajets**, tous avec transport |
| `parseIdfmJourneys` | **4 trajets** |
| `applyOfficialDisruptions`, avant correction | **0 trajet** |
| `applyOfficialDisruptions`, après correction | **4 trajets** |

Commande de reproduction de bout en bout :

```bash
bun --env-file=.env scripts/diagnostics/repro-suburban-journeys.ts \
  --count 1 \
  --requested-at 2026-08-28T13:00:00+02:00
```

Avant correction, elle échoue en moins d'une seconde avec `HTTP 200 / no-route / idfm-realtime / 0 transit`.

## 3. Cause racine

**La surcouche Via de perturbations officielles transformait des travaux limités à une station en fermeture de toute la ligne.**

Le payload bulk actif contient une perturbation bloquante « RER A : Nation du 29/06 au 30/08 » :

- la perturbation ne porte aucun `impactedSections` ;
- `lines[].impactedObjects` la rattache à la ligne A **et à l'arrêt Nation** ;
- le parseur Via ne conservait que le rattachement à la ligne et jetait l'arrêt ;
- le filtre d'itinéraire interprétait alors l'absence de segment comme « toute la ligne est suspendue ».

Chaque trajet ouest → Paris passant par le RER A était donc éliminé après que PRIM avait correctement renvoyé ses alternatives. L'origine Auber fonctionnait parce que ses trajets courts ne dépendaient pas de la ligne A.

## 4. Correctif v0.2.35

Le scope officiel est désormais conservé et appliqué avec cette priorité :

1. un `impactedSection` ne bloque que le trajet qui traverse ce segment ;
2. un `impactedStop` ne bloque que le trajet qui dessert cet arrêt ;
3. l'absence de segment **et** d'arrêt est la seule forme traitée comme une fermeture de ligne entière.

Le parseur récupère les arrêts depuis `lines[].impactedObjects` avec leur ligne, leur identifiant et leur nom. La clé Redis du snapshot passe de `v1` à `v2`, afin qu'aucun snapshot ancien ayant perdu ce scope ne survive au déploiement.

Deux tests verrouillent le cas réel :

- Chatou–Croissy → Auber reste proposé pendant les travaux de Nation ;
- un trajet qui dessert réellement Nation est bien retiré.

Les retries PRIM, le second avis GTFS et les améliorations du planificateur local livrés en v0.2.33–v0.2.34 restent des défenses utiles, mais ils ne corrigeaient pas cette cause située après les deux planificateurs.

## 5. Validation avant release

- `bun run --filter @via/api test` : **434 pass, 1 skip, 0 fail**.
- `bun run --filter @via/api typecheck` : **vert**.
- Payloads live PRIM journeys + disruptions, appliqués au code corrigé : **4 avant overlay, 4 après overlay**.
- Le test de régression a été observé rouge avant le correctif puis vert après.

## 6. Vérification post-déploiement

- [ ] Rejouer le harness Railway avec plusieurs IDs de cache uniques ; attendu : chaque réponse contient au moins un trajet transport.
- [ ] Vérifier dans l'app Maison → 15 rue Vivienne et Alicia → Chatou/La Défense.
- [ ] Vérifier qu'un trajet passant réellement par Nation respecte encore la perturbation bloquante.
