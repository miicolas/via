# Recherche de mots-clés — Metyro, store FR

**App :** Metyro · 6801259695 · **Store :** France (storefront 143442) · **Date :** 25/08/2026
**Intention :** téléchargements organiques au lancement, marché unique, budget d'acquisition nul.

---

## Méthode — et ce qu'elle vaut

Aucun fournisseur de volume payant n'est connecté (Astro / Appeeky MCP absents). Plutôt
que d'inventer des scores, les chiffres ci-dessous sont dérivés de **deux sources réelles
interrogées sur le storefront français**, conservées dans `docs/aso/data/` :

| Signal | Source | Ce qu'il mesure |
|---|---|---|
| **Volume** | Autocomplétion App Store FR (`MZSearchHints`, 80 requêtes amorces) | Apple ne suggère que ce qui est réellement cherché, et l'ordre des suggestions suit la popularité. Un terme sans suggestion a un volume quasi nul |
| **Difficulté** | SERP réelles FR (`itunes.apple.com/search`, 15 requêtes) | Masse d'avis des 3 premiers résultats — le mur d'autorité à franchir |
| **Pertinence** | Jugement manuel, adossé au code | 100 = Metyro fait exactement ça, vérifié dans `apps/via/via/` |

`Opportunité = Volume × 0,4 + (100 − Difficulté) × 0,3 + Pertinence × 0,3`

**Limite à garder en tête :** Volume et Difficulté sont des **proxys calibrés à la main sur
des signaux réels**, pas des mesures. Ils classent correctement les opportunités les unes
par rapport aux autres ; ils ne prédisent pas un nombre de téléchargements. Brancher Astro
ou Appeeky MCP remplacerait ces colonnes par du mesuré — c'est la seule amélioration
sérieuse possible de ce document.

---

## Résultats

| Requête | Vol | Diff | Pert | **Opp** | Rang actuel | Action |
|---|---|---|---|---|---|---|
| métro paris | 85 | 80 | 100 | **70,0** | — | Primaire → titre |
| transilien | 40 | 35 | 100 | **65,5** | — | Primaire → sous-titre ou mots-clés |
| prochain metro | 25 | 15 | 100 | **65,5** | — | Primaire → mots-clés |
| plan métro paris | 70 | 70 | 90 | **64,0** | — | Primaire → `plan` en mots-clés |
| transport ile de france | 75 | 85 | 95 | **63,0** | — | Secondaire → mots-clés |
| rer b / rer a / rer d | 40 | 30 | 85 | **62,5** | — | Longue traîne (non couvrable) |
| métro paris & rer | 65 | 75 | 95 | **62,0** | — | Primaire → titre |
| rer paris | 60 | 70 | 95 | **61,5** | — | Primaire → titre |
| horaire bus | 55 | 60 | 90 | **61,0** | — | Primaire → sous-titre × titre |
| transport paris | 65 | 80 | 95 | **60,5** | — | Secondaire |
| bus temps reel | 35 | 40 | 95 | **60,5** | — | Secondaire → sous-titre |
| trafic metro | 45 | 50 | 90 | **60,0** | — | Secondaire → sous-titre × titre |
| metro rer paris | 45 | 55 | 95 | **60,0** | — | Couvert par le titre |
| ratp | 85 | 90 | 70 | **58,0** | — | ⚠️ marque tierce — voir arbitrage |
| plan metro | 55 | 65 | 85 | **58,0** | — | Secondaire |
| bus paris | 55 | 70 | 90 | **58,0** | — | Couvert par le titre |
| station metro / ligne metro | 35 | 45 | 90 | **57,5** | — | Longue traîne → mots-clés |
| idf transport | 45 | 60 | 90 | **57,0** | — | Secondaire → `idf` |
| info trafic | 40 | 45 | 80 | **56,5** | — | Longue traîne |
| velib paris | 50 | 45 | 60 | **54,5** | — | ⚠️ marque tierce |
| transport en commun paris | 50 | 80 | 95 | **54,5** | — | Secondaire → `commun` |
| paris metropolitain | 20 | 25 | 80 | **54,5** | — | Longue traîne, marginal |
| trajet bus | 30 | 45 | 85 | **54,0** | — | Longue traîne |
| itineraire transport | 40 | 70 | 85 | **50,5** | — | Faible — voir ci-dessous |
| toilettes publiques paris | 30 | 25 | 40 | **46,5** | — | Écarté — fonctionnalité secondaire |
| navigo | 70 | 85 | 45 | **46,0** | — | ⚠️ marque tierce, écarté |
| idf mobilite | 60 | 90 | 60 | **45,0** | — | Écarté — requête de marque IDFM |
| ticket metro paris | 50 | 55 | 25 | **41,0** | — | Écarté — Metyro ne vend pas de titres |

---

## Ce que les données disent et qui n'était pas évident

**`itinéraire` est un piège en français.** C'est le mot que l'équipe produit emploie, donc
le réflexe est de le mettre partout. Mais l'autocomplétion FR sur `itineraire` renvoie :
vélo, course à pied, voyage, michelin, à pied, moto, voiture, marche à pied. Neuf
suggestions sur dix ne sont pas du transport en commun. Le mot est aujourd'hui dans le
champ mots-clés de Metyro et il y rapporte peu.

**`trafic` seul est un mot de jeu vidéo.** Trafic Rider, Trafic Racer, trafic maritime,
trafic aérien, trafic routier. En revanche `info trafic` est une vraie locution française
de transport (`info trafic sncf` est une suggestion), et `trafic métro` fonctionne par
combinaison. Donc : garder `trafic` **dans le sous-titre**, où il se combine avec le
`Métro` du titre, plutôt que de le payer isolé dans le champ mots-clés.

**`transilien` est le meilleur rapport qualité-prix du marché.** L'autocomplétion ne renvoie
que trois suggestions — signe d'une demande réelle mais d'un espace peu disputé — et deux
concurrents seulement le portent en sous-titre (Bonjour RATP, Ma Ligne). Metyro couvre
Transilien dans le code et n'en parle nulle part sur sa fiche.

**`prochain metro` a quatre résultats en tout.** Quatre. Dont deux apps à 1 et 4 avis.
C'est une requête que Metyro peut posséder dès la première semaine, et c'est littéralement
sa promesse produit.

**Le mur d'autorité est infranchissable à court terme sur les requêtes de tête.** Le top 3
de `metro paris` pèse 218 000 avis. Metyro en aura zéro. Viser `métro paris` en position 1
est une stratégie à 12 mois. Viser `prochain metro`, `transilien`, `bus temps reel`,
`trafic metro` est une stratégie à 30 jours — et ce sont exactement les requêtes où la
promesse de Metyro est la meilleure réponse du marché.

---

## Regroupement stratégique

**Primaires (titre + sous-titre)** — `métro`, `paris`, `rer`, `bus`, `horaire`, `trafic`, `temps réel`

**Secondaires (champ mots-clés)** — `transilien`, `plan`, `prochain`, `passage`, `station`,
`ligne`, `transport`, `commun`, `idf`, `ile`, `france`, `tram`

**Longue traîne (obtenue par combinaison, sans caractère supplémentaire)** — `station métro`,
`ligne métro`, `plan métro paris`, `horaire métro`, `trafic rer`, `prochain passage`,
`transport commun paris`, `idf transport`

**Aspirationnelles (à suivre, à ne pas sacrifier le reste pour elles)** — `ratp`, `navigo`,
`idf mobilite`, `citymapper`. Requêtes de marque, verrouillées par leurs propriétaires.

---

## Le levier des combinaisons inter-champs

Apple indexe nom, sous-titre et champ mots-clés séparément, puis **compose les requêtes
multi-mots à partir de tokens pris dans plusieurs champs**. C'est ce qui rend l'allocation
proposée efficace : un seul mot placé au bon endroit débloque plusieurs requêtes.

| Token ajouté | Où | Requêtes débloquées par combinaison |
|---|---|---|
| `plan` (4 car.) | mots-clés | `plan métro`, `plan métro paris`, `plan rer`, `plan bus` |
| `prochain` (8 car.) | mots-clés | `prochain métro`, `prochain rer`, `prochain bus`, `prochain passage` |
| `station` (7 car.) | mots-clés | `station métro`, `station rer`, `station paris` |
| `ligne` (5 car.) | mots-clés | `ligne métro`, `ligne rer`, `ligne bus`, `trafic ligne` |
| `commun` (6 car.) | mots-clés | `transport commun`, `transport en commun paris` |
| `Horaires` | sous-titre | `horaire métro`, `horaire rer`, `horaire bus`, `horaire paris` |
| `trafic` | sous-titre | `trafic métro`, `trafic rer`, `trafic bus`, `info trafic` |

Corollaire opérationnel : **ne jamais répéter un mot déjà présent dans le nom ou le
sous-titre**. Chaque répétition coûte des caractères et n'ajoute rien à l'index.

---

## Micro-optimisation vérifiée : `ile-de-france` → `ile,france`

Apple découpe sur le tiret et ignore les mots-outils comme `de`. `ile-de-france` (13 car.)
et `ile,france` (10 car.) produisent le même jeu de tokens indexés. **3 caractères
récupérés sans perte** — assez pour loger `tram`.

---

## Arbitrage : marques tierces

Quatre termes à forte demande sont des marques déposées que Metyro ne possède pas.

| Terme | Titulaire | Demande | Ce que font les concurrents tiers |
|---|---|---|---|
| `ratp` | RATP | très forte (10 suggestions) | **Transit** l'a en sous-titre (`Paris RATP, Lyon TCL…`), **Ma Ligne** aussi (`Infos RATP, RER & Transilien`) |
| `navigo` | Île-de-France Mobilités | forte | Bonjour RATP l'a en sous-titre — mais c'est l'app officielle |
| `vélib'` | Syndicat Autolib'/Vélib' Métropole | moyenne | fonctionnalité réellement livrée dans Metyro |
| `transilien` | SNCF | moyenne | Ma Ligne (tiers) l'a en sous-titre |

**La règle Apple** (5.2.1) interdit l'usage de marques tierces dans les métadonnées sans
autorisation. **La pratique observée** est que des apps tierces le font et sont publiées.

**Recommandation :** ne pas les mettre. Pas par excès de prudence, mais par arithmétique —
une soumission 1.0 rejetée pour métadonnées coûte un cycle de review complet, et `ratp`
est de toute façon la requête la plus verrouillée du marché : le top 3 y pèse 348 000 avis,
Metyro n'y apparaîtra pas cette année même en le mettant. Le gain espéré est proche de
zéro, le risque est un rejet.

**Exception à considérer :** `transilien` décrit un **réseau**, au même titre que `rer`, et
son usage est descriptif d'une couverture réelle. Le risque est nettement plus faible que
pour `ratp` ou `navigo`, et l'opportunité est la deuxième du tableau. La proposition de
métadonnées le retient.

**Si Nicolas décide d'assumer le risque après publication** — pas en 1.0 : ajouter `ratp`
(4 car.) au champ mots-clés dans une mise à jour ultérieure, quand un rejet ne coûte plus
qu'un aller-retour et non le lancement.

---

## À faire ensuite

1. Poser les métadonnées de `docs/aso/03-metadata.md`.
2. Après publication, relever le classement réel sur les 12 requêtes primaires et
   secondaires — c'est la seule mesure qui vaudra ces proxys.
3. Brancher Astro ou Appeeky MCP pour remplacer les colonnes Volume/Difficulté par du mesuré.
4. Rejouer cette recherche chaque trimestre : les requêtes transport bougent avec les
   grèves, les JO, les extensions de ligne et les saisons.
