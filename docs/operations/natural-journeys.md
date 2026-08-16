# Exploitation de la recherche en langage naturel

La fonctionnalité est contrôlée côté API. Aucune clé OpenAI ne doit être placée dans l’application iOS ou dans le dépôt.

## Configuration

- créer un projet OpenAI dédié et une clé restreinte à ce projet ;
- fournir `OPENAI_API_KEY` au serveur uniquement ;
- conserver `OPENAI_MODEL=gpt-5.6-luna` ;
- fixer le budget du projet à 25 USD par mois et créer des alertes à 50 %, 80 % et 100 % dans la console OpenAI ;
- vérifier les tarifs configurés par `OPENAI_INPUT_COST_PER_MILLION` et `OPENAI_OUTPUT_COST_PER_MILLION` avant chaque déploiement.

Les phrases et les positions ne sont pas journalisées. Les métriques autorisées sont le statut, l’intention structurée, la clarification, la latence, la source du trajet, le repli, le modèle, la version de prompt, les tokens, le coût estimé et le code d’erreur.

## Validation et rollout

1. Exécuter `bun run --filter @via/api eval:natural` hors CI avec la clé dédiée. Le script échoue sous 95 % d’intentions entièrement correctes ou dès qu’une origine, une destination ou un sens temporel est silencieusement erroné.
2. Déployer avec `NATURAL_JOURNEYS_ROLLOUT_PERCENT=10` et surveiller le p95, le taux de clarification, les replis déterministes, les erreurs et le coût.
3. Passer à 50 %, puis à 100 % uniquement après validation de ces métriques.
4. Utiliser `NATURAL_JOURNEYS_ENABLED=false` comme arrêt immédiat. Le coupe-circuit automatique s’ouvre après cinq échecs consécutifs pendant 60 secondes par défaut.

Le quota IA est indépendant de la recherche classique : 20 validations par identité anonyme et par fenêtre de 15 minutes par défaut.
