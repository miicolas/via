# Incident — « Aucun itinéraire en transport » depuis la banlieue

**Date** : 27 août 2026 · **Statut** : correctifs mergés sur `main` (v0.2.33), déploiement Railway en cours de vérification · **Sévérité** : majeure (fonctionnalité cœur inutilisable depuis la grande couronne)

---

## 1. Symptôme

Une recherche d'itinéraire depuis une adresse de banlieue (Chatou, Carrières-sous-Poissy — favoris « Maison », « Alicia ») vers Paris ou La Défense affichait **« Aucun itinéraire en transport »**, alors que le trajet réel existe (marche + bus + RER/Transilien + métro). Les tuiles à pied / à vélo s'affichaient normalement.

- Depuis une **station épinglée** (Auber, Bonne Nouvelle) : toujours des résultats, badge vert « Temps réel ».
- Depuis une **adresse de banlieue** : échec apparent­­ement aléatoire — « des fois ça marche, des fois non ».
- Impression que « ça marchait avant la feature vélos/marche ».

## 2. Cause racine

**Le load balancer de PRIM (IDFM) a un backend Navitia désynchronisé.** Il répond `HTTP 200` avec **zéro itinéraire** (sans même un `error.id`) environ **une fois sur deux** aux requêtes venant du chemin réseau de Railway (GCP europe-west4) — jamais depuis d'autres chemins réseau. Les trajets intra-Paris survivent même sur le backend malade ; les trajets de banlieue (bus + train) n'y existent pas.

Le serveur Via prenait cette réponse vide pour argent comptant : `no-route`, sans repli, sans log. La corrélation avec la feature vélos/marche était une **coïncidence temporelle** — la requête PRIM générée avant et après (#55) donne un résultat identique, testé au byte près.

### Preuve (mesures du 27/08, clé de prod)

| Chemin | Requêtes | Résultat |
|---|---|---|
| Prod Railway → PRIM (Maison → Vivienne) | 19 sondes | **~50 % `no-route`**, aléatoire pur, toujours `source: idfm-realtime` |
| Direct → PRIM, même clé, même URL byte-exacte (générée par `journeyUrl()` du repo), en-têtes Bun clonés, HTTP/1.1 **et** HTTP/2 | **26 appels** | **26/26 → 4 itinéraires** (bus 6427/6502/6529 › RER A ou Transilien J › métro 3) |

Éliminé un à un, mesures à l'appui : la clé (le compteur `ratelimit-remaining` PRIM décrémente avec les sondes prod → **même clé**, quota intact ~920/1000), l'URL (toutes les formes historiques testées), le parseur (le corps réel de PRIM passé dans `parseIdfmJourneys` → 4 itinéraires), l'horloge serveur (`generatedAt` juste), le cache, les filtres de modes, le décodage iOS (il lève, ne filtre pas), le favori (coordonnées exactes sur le fil), la feature vélos/marche.

## 3. Facteurs aggravants (dans notre code)

La réponse vide de PRIM n'aurait dû coûter qu'un repli — mais le filet de sécurité était troué à quatre endroits :

1. **Le repli GTFS n'était jamais consulté sur une réponse vide** (`service.ts`) : seul un échec de l'appel (timeout, quota, erreur réseau) le déclenchait. Un `200` vide arrêtait tout.
2. **Le planificateur GTFS local ne savait pas construire un trajet de banlieue** :
   - les 8 arrêts d'accès triés par distance pure : 8 poteaux de bus évinçaient la gare RER à 900 m (Chatou) ;
   - la requête de candidats (LIMIT 1500, tri horloge) affamait les arrêts atteints en fin de premier trajet ;
   - la coupe du front d'exploration (512 labels) jetait l'arrêt de correspondance au profit de variantes Pareto.
3. **Timeout PRIM à 2,5 s**, jamais mesuré : les réponses de banlieue pèsent 376 ko (géométries) contre 114 ko intra-Paris — les trajets qui en avaient le plus besoin étaient les premiers coupés.
4. **Aucun log** ne nommait le planificateur derrière une réponse vide — l'incident était indiagnosticable a posteriori.

## 4. Correctifs livrés (branche `claude/favoris-comportement-bug-ymc6zz` → staging #59 → main v0.2.33)

Défense en profondeur, 300 tests + `tsc` au vert :

| Commit | Correctif |
|---|---|
| `592ced6` | **Retry PRIM** : une réponse vide est redemandée une fois (un vrai « aucune ligne » est reproductible, un backend malade non). 50 % → 25 % d'échec, log `[journeys] réponse IDFM vide, seconde demande` |
| `8a1295d` | **Second avis GTFS** : toute réponse IDFM sans rien à prendre est contre-vérifiée par l'horaire local. Le temps réel garde la main dès qu'il a quelque chose |
| `90af1d1` | **Arrêts d'accès** : places réservées aux stations métro/RER/Transilien/tram accessibles à pied, en plus des 8 plus proches |
| `a14d1a3` | **Candidats + front** : requêtes groupées par moment d'atteinte, classement par temps d'attente, meilleur label par arrêt conservé |
| `f187ef9` | **Timeout PRIM 2,5 s → 5 s**, justifié par les latences mesurées (0,5–1,2 s, 4× de marge) |
| `e55c04b` | **Log** : toute réponse sans transport nomme sa source et la forme de la requête |
| `f1f8ed7` | **Boot** : avertissement si l'API démarre sans clé PRIM (dégradation silencieuse auparavant) |

Résultat attendu : échec visible ≈ 0 — retry (25 % résiduel) puis GTFS réparé (toujours un itinéraire théorique). Le badge « Temps réel » absent signale les réponses venues du repli.

## 5. Actions restantes

- [ ] **Vérifier le déploiement** : 16 sondes post-deploy en cours (attendu : 16/16 `ready` contre ~50 % avant).
- [ ] **Faire tourner 3 secrets** partagés dans la conversation de debug : clé PRIM (`API_KEY_PRISM_IDFM`), mot de passe Postgres Railway, clé client (`VIA_APP_CLIENT_KEYS`). À faire après confirmation du déploiement.
- [ ] **Signaler à IDFM/PRIM** : « `/marketplace/v2/navitia/journeys` renvoie 200 avec 0 journey de façon intermittente (~50 %) depuis GCP europe-west4, reproductible sur trajets banlieue→Paris, aucun `error.id` ». Tant que leur nœud n'est pas purgé, chaque trajet de banlieue coûte un appel PRIM sur deux en double.
- [ ] Optionnel : `disable_geojson=true` + hydratation locale des tracés diviserait le poids des réponses par ~3 (376 ko → ~100 ko) — à tester côté rendu carte avant.

## 6. Observations annexes (hors incident)

- La géolocalisation d'un appareil de test remontait Niort (`46.22, -0.85`) dans `/api/search` — sans effet sur les itinéraires (l'origine vient du favori), mais dégrade le classement des résultats de recherche.
- La BAN (géocodeur d'adresses) a eu un incident passager (`AbortError` à 4 s) pendant le diagnostic — revenue seule.
- Les trois gouverneurs PRIM (stop-monitoring 1000 + journeys 1000 + disruptions 800) autorisent ensemble 2 800 appels/jour contre un jeton à 1 000 — sans incidence ici (42 appels consommés ce jour-là), mais à unifier un jour.
