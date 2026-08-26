# 0003 — API réservée aux clients de première partie

- Statut : accepté
- Date : 2026-08-23

## Contexte

L’API répondait à n’importe quel appelant. `cors()` était monté sans option sur `/api`, `/rpc` et `/public`, le HOTFIX « no-account » laisse passer les requêtes anonymes, et `/api/openapi.json` publiait le contrat complet. Deux clients existent pourtant : l’app iOS et le site marketing. Tout le reste — scrapers, clients clonés, tests de charge — consommait le quota PRIM (1 000 requêtes/jour), le budget OpenAI et la base sans jamais se nommer.

Les deux clients ne peuvent pas prouver la même chose. Un binaire iOS peut embarquer un secret, extractible mais coûteux à trouver. Une page web ne peut rien garder : seule son origine, posée par le navigateur et non falsifiable par une autre page, la distingue.

## Décision

1. Une porte d’entrée unique, `apps/api/src/http/client-gate.ts`, montée au-dessus de tous les routeurs — Better Auth compris — pour qu’une route ajoutée plus tard soit privée sans qu’on y pense.
2. L’app présente un secret partagé dans l’en-tête `x-via-client-key` sur `/api` et `/rpc`. Il est comparé en temps constant contre `VIA_APP_CLIENT_KEYS`, une liste, pour qu’une clé tourne pendant qu’un build précédent vit encore sur les appareils.
3. Le site est reconnu par son origine (`VIA_ALLOWED_ORIGINS`) pour ce qu’il fait depuis la page, et par `VIA_SITE_CLIENT_KEYS` pour ce que Next rend côté serveur, où aucune origine n’existe.
4. CORS n’accepte plus que ces origines. La liste vide conserve le comportement précédent.
5. `/api/health` reste ouvert : la sonde de la plateforme ne porte pas de clé et n’apprend rien. `/api/openapi.json` passe derrière la porte, parce que donner la carte est l’essentiel du travail de clonage.
6. Une variable non renseignée laisse la surface correspondante ouverte et le journal de démarrage la nomme. Un `.env` vide fait donc tourner le dépôt, et un déploiement se ferme en remplissant ses variables.
7. La clé de l’app vit dans `apps/via/Configuration/Secrets.xcconfig`, non suivi par git, inclus optionnellement par `Shared.xcconfig`.

## Amendement du 2026-08-26 — la surface `/public`

Le blog « Travaux & trafic » du site a besoin de l’état des lignes et des perturbations, que seul le contrat sait produire. Plutôt que d’ouvrir le contrat au site, `/public` accueille une seconde exception explicite, `/public/lines/statuses` et `/public/lines/detail`, sur le modèle exact de `/public/city-demand`.

Règle qui rend ces mounts sûrs : **chaque route `/public` est une projection écrite à la main** (`apps/api/src/public/lines/projection.ts`), jamais une réponse du contrat transmise telle quelle. Les deux routes sont en lecture seule, et la projection retire le schéma de ligne — le site en embarque son propre instantané commité — ainsi que le champ `message` du flux IDFM, dont la republication n’aurait aucune valeur éditoriale.

La conséquence à tenir : ajouter une procédure au contrat ne doit jamais suffire à la rendre publique. Si un jour une route `/public` se contente de réexporter une réponse du contrat, cet ADR est violé même si aucune ligne de `client-gate.ts` n’a bougé.

## Conséquences

- La clé de l’app est extractible du binaire. Elle relève le coût du clonage, elle ne remplace ni la session ni les quotas par personne. Le durcissement suivant est App Attest, qui prouve l’appareil au lieu de faire confiance au binaire.
- Un build publié sans clé est refusé par un environnement fermé (`403 unknown_client`) sur toutes les routes. La configuration serveur et la publication d’un build porteur de la clé doivent donc être ordonnées.
- Le vote du site depuis le navigateur ne repose que sur l’origine et sur le quota par adresse déjà en place ; un appelant hors navigateur peut forger `Origin`. C’est accepté : ce point d’entrée n’écrit qu’un compteur de villes.
- Un nouveau client de première partie n’a pas besoin de code : une clé de plus dans la liste.
