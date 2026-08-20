# 0001 — Recherche en langage naturel hybride, on-device d’abord

- Statut : remplacé par ADR-0002
- Date : 2026-08-17

Cette décision est conservée comme historique. La recherche hybride et son fallback LLM serveur ont été remplacés par une recherche exclusivement locale pour l’interprétation.

## Contexte

Via exposait deux implémentations redondantes pour transformer une phrase en français en itinéraire : un flux serveur `natural-journeys` utilisé par l’application et une architecture de chat Foundation Models non branchée. L’ancien endpoint de chat, le code iOS associé et un bouton désactivé n’avaient aucun client actif. La résolution des clarifications existait dans le contrat, mais l’application n’émettait jamais de requête `resolve`.

Le géocodage et le calcul d’itinéraires restent des opérations serveur. « On-device » désigne donc uniquement l’interprétation de l’intention et la rédaction de la réponse.

## Décision

La recherche en langage naturel utilise un dépôt composite `HybridNaturalJourneyRepository` :

1. Lorsque Foundation Models est disponible pour `fr_FR`, l’appareil interprète la phrase avec une génération guidée `@Generable`.
2. Le service iOS résout les lieux via `/api/search`, calcule jusqu’à quatre itinéraires via `/api/journeys`, puis demande au modèle une réponse fondée sur ces faits.
3. La réponse générée est validée contre les lieux, lignes, horaires, durées et avertissements réels. Toute génération absente, refusée ou invalide produit une réponse déterministe.
4. Une erreur du modèle pendant l’interprétation déclenche silencieusement le dépôt serveur `natural-journeys`.
5. Si le modèle n’est pas disponible, la requête, y compris `resolve`, part directement au serveur.
6. Une erreur réseau du pipeline on-device est propagée comme `Loadable.failed`; elle ne relance pas le même réseau via le chemin distant.
7. Un état explicatif Apple Intelligence n’est présenté que lorsque le chemin serveur échoue lui aussi et que la cause locale est actionnable : activation désactivée ou modèle en téléchargement.

Les deux chemins retournent le même `NaturalJourneyResult`. `answerSource` distingue `onDevice`, `server` et `deterministic`. La clarification réutilise `NaturalJourneyDraft`, `NaturalJourneyClarification` et `NaturalJourneyRequest.resolve`; l’interface traite le premier champ dans l’ordre fourni par le service.

Le périmètre ne comprend aucun chat. L’ancien endpoint dédié et tout le code iOS `Features/Chat` sont supprimés.

## Conséquences

- Le contrat oRPC existant ne change pas. Les valeurs serveur `ai` et `deterministic` sont adaptées au domaine iOS.
- Le validateur anti-hallucination existe en TypeScript et en Swift. Toute évolution des faits autorisés, des claims ou du vocabulaire de perturbation doit maintenir les deux ports en miroir.
- Le corpus d’évaluation serveur est repris par les tests iOS Foundation Models avec les mêmes identifiants. Ces évaluations sont informatives et ignorées lorsque le modèle n’est pas disponible.
- Le pipeline on-device n’applique ni rate-limit IA, ni horizon GTFS, ni liste locale de municipalités. Le serveur conserve ces garde-fous lorsqu’il interprète la requête.
- Le géocodage et le calcul restent connectés : le mode avion aboutit à l’erreur réseau et à l’action « Réessayer » existante.
- `LanguageModelSession` est créée pour chaque génération et n’est jamais stockée, afin de respecter son isolation sous Swift 6.
- Les journaux enregistrent uniquement le chemin, la latence, la source de réponse, le statut et la raison de bascule. La phrase de l’utilisateur n’est jamais journalisée.
