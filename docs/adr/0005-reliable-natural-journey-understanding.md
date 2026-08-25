# 0005 — Compréhension fiable des demandes de trajet

- Statut : accepté
- Date : 2026-08-26
- Remplace : ADR-0004

## Contexte

L’ADR-0004 branchait deux produits différents : le chemin local interprétait puis
résolvait les lieux dans l’app, tandis que le chemin serveur interprétait,
géocodait et planifiait avec ses propres outils. Une même phrase pouvait donc
changer de sens selon la disponibilité du modèle. Le serveur recevait aussi les
responsabilités les plus risquées : choisir les lieux et construire le trajet.

Le cas critique « rentrez chez moi depuis Auber » montre la limite de cette
architecture. « depuis Auber » et « chez moi » sont des faits explicites, pas des
suggestions qu’un modèle peut inverser ou transformer en requête géographique.

## Décision

1. Via possède un pipeline unique : **ancrage → interprétation typée → fusion et
   validation → résolution locale des lieux → planification locale**.
2. Une ancre déterministe porte une valeur, le fragment qui la justifie, sa
   provenance et son niveau de confirmation. Une ancre verrouillée ne peut être
   remplacée que par une correction explicite visant ce champ.
3. Les lieux ont quatre formes canoniques : position actuelle, lieu enregistré,
   requête géographique et référence conversationnelle. La planification ne
   manipule jamais « chez moi » comme texte à géocoder.
4. Maison, Travail et les lieux personnalisés existent uniquement après
   enregistrement explicite. Une Maison absente ouvre un choix dédié : choisir
   pour cette fois ou choisir et enregistrer Maison.
5. Le modèle local et le modèle serveur proposent le même patch sémantique. Le
   serveur est **interprète uniquement** : aucun accès aux coordonnées
   personnelles, à la recherche de lieux ou au planificateur.
6. Les formulations complètement déterministes contournent le modèle. Un échec
   technique local peut utiliser le serveur si la préférence l’autorise. Un
   refus de sécurité et une annulation ne déclenchent jamais ce repli.
7. La fusion a trois sorties : exécution lorsque les faits sont uniques et
   suffisamment fondés, clarification ciblée lorsque deux interprétations
   restent plausibles, refus explicite lorsque la demande est hors déplacement
   ou insuffisamment fondée. Aucun fragment significatif n’est ignoré.
8. Le dialogue ne vit que pendant la recherche courante. Les lieux et champs
   confirmés restent verrouillés entre les tours ; fermer ou réussir la recherche
   détruit la phrase et l’état de session.
9. Le français et l’anglais sont les deux contrats garantis. Les autres langues
   peuvent fonctionner opportunément sans promesse équivalente.
10. Le repli serveur est actif par défaut après information explicite. Le mode
    local uniquement est disponible dans Réglages. La phrase n’est jamais
    conservée ni incluse dans les métriques ; un envoi détaillé exige une action
    volontaire ouvrant un aperçu de partage.
11. Les métriques anonymes séparent version iOS, chemin déterministe/local/serveur
    et étape interprétation/résolution/planification. Les budgets p95 sont 2,5 s
    pour l’interprétation locale, 5 s pour le serveur et 8 s jusqu’au premier
    résultat.
12. Le repli serveur est activé progressivement par identité pseudonymisée.
    `NATURAL_JOURNEYS_REMOTE_ROLLOUT_PERCENT=0` est le kill switch immédiat.
    La valeur serveur par défaut reste 0 ; chaque environnement l’augmente
    explicitement après validation des gates.
    Aucun lancement n’est accepté sans 100 % sur le corpus critique, 99 % sur le
    corpus général et le scénario Auber → Maison validé de bout en bout.

## Conséquences

- Le serveur nominal ne peut plus inverser un trajet, choisir une adresse ou
  produire un itinéraire : l’app conserve toute l’autorité.
- Un désaccord entre règle et modèle devient visible au lieu d’être résolu par
  la confiance déclarée du modèle.
- Le chemin historique agent + outils peut rester temporairement testable pour
  rollback, mais il n’est ni appelé par la route nominale ni considéré comme un
  second fallback.
- La promesse publique est précise : « traité sur cet iPhone quand c’est
  possible, sinon par le serveur sécurisé », avec contrôle local uniquement.

## Références

La recherche et les sources primaires qui motivent les sorties structurées,
l’ancrage, la calibration sélective et les évaluations par tranches sont
documentées dans `docs/research/reliable-natural-journey-intelligence-architecture.md`.
