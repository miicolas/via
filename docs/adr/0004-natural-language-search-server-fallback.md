# 0004 — Repli serveur pour la recherche en langage naturel

- Statut : remplacé par ADR-0005
- Date : 2026-08-25
- Remplace : ADR-0002 (décisions 6, 8 et 9)

## Contexte

L'ADR-0002 supprimait tout fallback LLM serveur : les appareils sans Apple Intelligence perdaient la recherche en langage naturel, et une panne transitoire du modèle local aboutissait à un cul-de-sac. Le commit `74115f83` a réintroduit côté API un agent OpenAI borné (`POST /api/natural-journeys`) — garde-fous en cascade, outils opaques `search_places`/`plan_journeys`, `store: false`, identité pseudonymisée — sans le brancher côté iOS. Ce document acte le branchement.

## Décision

1. L'interprétation reste locale d'abord : `HybridNaturalJourneyService` route chaque soumission initiale vers `OnDeviceNaturalJourneyService` quand Foundation Models est disponible.
2. Le serveur (`RemoteNaturalJourneyService`) prend le relais dans exactement deux cas : le modèle local est indisponible (appareil non éligible, Apple Intelligence désactivée, modèle pas prêt, langue non prise en charge), ou il échoue pour une raison système transitoire (`modelNotReady`, `modelFailed`).
3. Une phrase que le modèle local a **refusée** (`contentRefused`, `unsupportedLanguage`, `contextWindowExceeded`, `invalidResponse`) n'est jamais transmise au serveur : le refus local est une réponse, pas une panne.
4. Les clarifications et décisions restent intégralement on-device : le contrat serveur ne connaît que `ready`, `unsupported` et `unavailable`, et le repository distant ne reçoit jamais de brouillon.
5. Les accès Apple Intelligence sont actifs sur tous les appareils (`naturalLanguageAvailability = .available` à l'injection) : un appareil non éligible passe simplement par le serveur.
6. La promesse produit devient : « comprise sur cet iPhone quand c'est possible, sinon par le serveur sécurisé de Metyro » (texte de l'onboarding mis à jour).
7. Sans `OPENAI_API_KEY` côté serveur, la route répond `outcome: unavailable`, que l'app présente comme un échec réessayable avec bascule vers la recherche classique.

## Conséquences

- La décision 8 de l'ADR-0002 (« la phrase n'est jamais envoyée au serveur ») ne tient plus pour les cas de repli ; la phrase transite alors par l'API de Via puis OpenAI (`store: false`, identifiant pseudonymisé), et n'est toujours ni conservée ni journalisée par Via.
- L'audience de la recherche naturelle s'étend aux appareils non éligibles à Apple Intelligence.
- Le client OpenAPI généré inclut désormais `naturalJourneys.submit` (`openapi-generator-config.yaml`).
