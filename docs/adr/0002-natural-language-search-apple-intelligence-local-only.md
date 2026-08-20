# 0002 — Recherche en langage naturel Apple Intelligence locale uniquement

- Statut : accepté
- Date : 2026-08-20
- Remplace : ADR-0001

## Contexte

Via possède un moteur fiable de géocodage et de calcul d’itinéraires, ainsi qu’un parseur Foundation Models capable d’extraire une intention structurée en français. L’ancienne architecture ajoutait un second LLM côté serveur lorsque le modèle local était indisponible ou échouait. Ce fallback contredisait la promesse produit selon laquelle la phrase libre reste sur l’appareil et dupliquait l’interprétation, les garde-fous et le contrat.

## Décision

1. Foundation Models sert uniquement à extraire une intention structurée avec `@Generable`. Il ne rédige aucune réponse et n’invente aucun horaire.
2. Le géocodage passe par `/api/search` et le calcul de quatre itinéraires par `/api/journeys`.
3. Les résultats, leur classement et leur résumé sont déterministes et proviennent du moteur Via.
4. Si le modèle est disponible et prend en charge le français, les accès Apple Intelligence sont actifs.
5. Si Apple Intelligence est désactivée ou si son modèle est en téléchargement, l’accès reste visible et explique la récupération possible.
6. Si l’appareil n’est pas éligible ou si le français n’est pas pris en charge, l’accès est masqué et la recherche classique reste inchangée.
7. Une contradiction, une ambiguïté ou une contrainte non supportée exige une décision explicite. Aucun critère n’est supprimé silencieusement.
8. La phrase n’est ni conservée dans un historique, ni envoyée au serveur, ni journalisée.
9. Le fallback OpenAI, le contrat `natural-journeys`, son endpoint, ses variables d’environnement et ses dépendances sont supprimés.

## Conséquences

- Les utilisateurs non éligibles conservent la recherche classique, sans équivalent LLM distant.
- L’interprétation peut fonctionner hors ligne, mais le géocodage et les horaires nécessitent une connexion.
- Les mises à jour du modèle livrées avec iOS imposent un corpus français de non-régression.
- Les métriques autorisées se limitent aux durées, statuts et nombres de corrections ; elles ne contiennent jamais la phrase, les lieux ou l’itinéraire.
