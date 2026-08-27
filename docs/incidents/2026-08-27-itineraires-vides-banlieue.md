# Incident — « Aucun itinéraire en transport » depuis la banlieue

**Date** : 27 août 2026 · **Statut** : résolu, déployé en v0.2.34 · **Sévérité** : majeure (fonctionnalité cœur inutilisable depuis la grande couronne)

---

## 1. Symptôme

Une recherche d'itinéraire depuis une adresse de banlieue (Chatou, Carrières-sous-Poissy — favoris « Maison », « Alicia ») vers Paris ou La Défense affichait **« Aucun itinéraire en transport »**, alors que le trajet réel existe (marche + bus + RER/Transilien + métro). Les tuiles à pied / à vélo s'affichaient normalement.

- Depuis une **station épinglée** (Auber, Bonne Nouvelle) : toujours des résultats, badge vert « Temps réel ».
- Depuis une **adresse de banlieue** : échec apparent­­ement aléatoire — « des fois ça marche, des fois non ».
- Impression que « ça marchait avant la feature vélos/marche ».

## 2. Cause racine

**Un backend Navitia désynchronisé derrière le load balancer de PRIM, auquel notre serveur restait collé par keep-alive.**

Deux moitiés, et c'est la seconde qui explique pourquoi ça durait :

1. **Côté PRIM** : un backend du pool répond `HTTP 200` avec **zéro itinéraire**, sans même un `error.id`. Les trajets intra-Paris y survivent ; les trajets de banlieue (bus + train) n'y existent pas.
2. **Côté nous** : `fetch` de Bun garde sa connexion ouverte et la réutilise, et le load balancer associe une connexion à un backend. Une connexion tombée sur le backend malade y renvoie **toutes** les requêtes suivantes, pendant toute sa durée de vie.

D'où le symptôme : des **séries** d'échecs puis des séries de succès, jamais du hasard requête par requête. Et d'où l'échec du premier correctif — un retry dans le même tuyau redemande au même backend cassé.

Le serveur prenait par ailleurs cette réponse vide pour argent comptant : `no-route`, sans repli, sans log. La corrélation avec la feature vélos/marche était une **coïncidence temporelle** — la requête PRIM générée avant et après (#55) donne un résultat identique, testé au byte près.

### Preuve (mesures du 27/08, clé de prod)

| Chemin | Requêtes | Résultat |
|---|---|---|
| Prod Railway → PRIM (Maison → Vivienne) | ~50 sondes | échecs **en séries** : 10 succès d'affilée, puis 8 échecs d'affilée, puis 6 succès — toujours `source: idfm-realtime` |
| Direct → PRIM (connexion neuve à chaque appel), même clé, même URL byte-exacte (générée par `journeyUrl()` du repo), en-têtes Bun clonés, HTTP/1.1 **et** HTTP/2 | **26 appels** | **26/26 → 4 itinéraires** (bus 6427/6502/6529 › RER A ou Transilien J › métro 3) |
| `Connection: close` honoré par Bun ? | test local apparié | **oui** — deux sockets distincts au lieu d'un seul réutilisé |

La forme en séries est la signature décisive : un tirage indépendant par requête donnerait un mélange, pas des blocs. La seule variable distinguant les deux appelants est la réutilisation de la connexion.

Éliminé un à un, mesures à l'appui : la clé (le compteur `ratelimit-remaining` PRIM décrémente avec les sondes prod → **même clé**, quota intact ~920/1000), l'URL (toutes les formes historiques testées), le parseur (le corps réel de PRIM passé dans `parseIdfmJourneys` → 4 itinéraires), l'horloge serveur (`generatedAt` juste), le cache, les filtres de modes, le décodage iOS (il lève, ne filtre pas), le favori (coordonnées exactes sur le fil), la feature vélos/marche, et — hypothèse émise puis écartée — la réplique multi-région de `railway.json`.

## 3. Facteurs aggravants (dans notre code)

La réponse vide de PRIM n'aurait dû coûter qu'un repli — mais le filet de sécurité était troué à quatre endroits :

1. **Le repli GTFS n'était jamais consulté sur une réponse vide** (`service.ts`) : seul un échec de l'appel (timeout, quota, erreur réseau) le déclenchait. Un `200` vide arrêtait tout.
2. **Le planificateur GTFS local ne savait pas construire un trajet de banlieue** :
   - les 8 arrêts d'accès triés par distance pure : 8 poteaux de bus évinçaient la gare RER à 900 m (Chatou) ;
   - la requête de candidats (LIMIT 1500, tri horloge) affamait les arrêts atteints en fin de premier trajet ;
   - la coupe du front d'exploration (512 labels) jetait l'arrêt de correspondance au profit de variantes Pareto.
3. **Timeout PRIM à 2,5 s**, jamais mesuré : les réponses de banlieue pèsent 376 ko (géométries) contre 114 ko intra-Paris — les trajets qui en avaient le plus besoin étaient les premiers coupés.
4. **Aucun log** ne nommait le planificateur derrière une réponse vide — l'incident était indiagnosticable a posteriori.

## 4. Correctifs livrés (branche `claude/favoris-comportement-bug-ymc6zz` → staging → main v0.2.34)

Défense en profondeur, 301 tests + `tsc` au vert :

| Commit | Correctif |
|---|---|
| `592ced6` + v0.2.34 | **Retry PRIM sur une connexion neuve** : une réponse vide est redemandée une fois, avec `Connection: close` — sortir du pool est un **nouveau tirage** du load balancer. Sans ça le retry retombait sur le même backend cassé. Log `[journeys] réponse IDFM vide, seconde demande sur une connexion neuve` |
| `8a1295d` | **Second avis GTFS** : toute réponse IDFM sans rien à prendre est contre-vérifiée par l'horaire local. Le temps réel garde la main dès qu'il a quelque chose. Un second avis vide laisse désormais son propre verdict en log (`status`, `reason`) |
| `90af1d1` | **Arrêts d'accès** : places réservées aux stations métro/RER/Transilien/tram accessibles à pied, en plus des 8 plus proches |
| `a14d1a3` | **Candidats + front** : requêtes groupées par moment d'atteinte, classement par temps d'attente, meilleur label par arrêt conservé |
| `f187ef9` | **Timeout PRIM 2,5 s → 5 s**, justifié par les latences mesurées (0,5–1,2 s, 4× de marge) |
| `e55c04b` | **Log** : toute réponse sans transport nomme sa source et la forme de la requête |
| `f1f8ed7` | **Boot** : avertissement si l'API démarre sans clé PRIM (dégradation silencieuse auparavant) |

Résultat attendu : échec visible ≈ 0 — le retry sort du tuyau collé, et si le nouveau tirage retombe malgré tout sur le backend malade, le GTFS réparé prend le relais avec un itinéraire théorique. Le badge « Temps réel » absent signale les réponses venues du repli.

## 5. Actions restantes

- [x] **Déploiement vérifié** : v0.2.33 puis v0.2.34 sur `main`, 301 tests + `tsc` verts. Sondes post-v0.2.33 : 10/10 puis 6/6 sur les fenêtres saines, échecs en séries sur les fenêtres collées — d'où v0.2.34.
- [ ] **Confirmer v0.2.34** : 20 sondes post-déploiement (attendu : plus de séries d'échecs).
- [ ] **Faire tourner 3 secrets** partagés dans la conversation de debug : clé PRIM (`API_KEY_PRISM_IDFM`), mot de passe Postgres Railway, clé client (`VIA_APP_CLIENT_KEYS`). À faire après confirmation du déploiement.
- [ ] **Signaler à IDFM/PRIM** : « `/marketplace/v2/navitia/journeys` renvoie 200 avec 0 journey depuis GCP europe-west4, **par séries corrélées à la connexion keep-alive** — un backend du pool est désynchronisé. Reproductible sur trajets banlieue→Paris, aucun `error.id`. » Tant que leur nœud n'est pas purgé, chaque trajet touché coûte un appel PRIM et une poignée de main en plus.
- [ ] Optionnel : `disable_geojson=true` + hydratation locale des tracés diviserait le poids des réponses par ~3 (376 ko → ~100 ko) — à tester côté rendu carte avant.

## 6. Observations annexes (hors incident)

- La géolocalisation d'un appareil de test remontait Niort (`46.22, -0.85`) dans `/api/search` — sans effet sur les itinéraires (l'origine vient du favori), mais dégrade le classement des résultats de recherche.
- La BAN (géocodeur d'adresses) a eu un incident passager (`AbortError` à 4 s) pendant le diagnostic — revenue seule.
- Les trois gouverneurs PRIM (stop-monitoring 1000 + journeys 1000 + disruptions 800) autorisent ensemble 2 800 appels/jour contre un jeton à 1 000 — sans incidence ici (42 appels consommés ce jour-là), mais à unifier un jour.
