# ASO Audit — Metyro (fr-FR)

**App :** Metyro · 6801259695 · **Store :** France · **Plateforme :** iOS
**Version auditée :** 1.0 (`PREPARE_FOR_SUBMISSION`) · **Date :** 25/08/2026
**Source métadonnées :** `asc metadata pull --app 6801259695 --version 1.0` — le dépôt et
App Store Connect sont identiques, il n'y a pas de dérive.

---

## Score

```
Score ASO global : 30/100

Titre               2/10  ██░░░░░░░░
Sous-titre          7/10  ███████░░░
Champ mots-clés     5/10  █████░░░░░
Description         6/10  ██████░░░░
Captures            0/10  ░░░░░░░░░░
Vidéo d'aperçu      0/10  ░░░░░░░░░░
Notes & avis        0/10  ░░░░░░░░░░   ← structurel : app non publiée
Icône               7/10  ███████░░░
Classements         0/10  ░░░░░░░░░░   ← structurel : app non publiée
Signaux conversion  3/10  ███░░░░░░░
```

**Lecture du score.** 30 points sur 100 sont structurellement inaccessibles avant
publication (notes, classements, et une part de la vidéo). Le chiffre utile est le
**score sur ce qui est contrôlable aujourd'hui : 30 / 70**, et l'essentiel du déficit
tient à trois choses — un titre vide, un champ mots-clés mal ciblé, et zéro capture.

---

## Utilisation des champs

| Champ | Valeur | Long. | Limite | Usage |
|---|---|---|---|---|
| Nom | `Metyro` | 6 | 30 | **20 %** |
| Sous-titre | `Métro Paris en temps réel` | 25 | 30 | 83 % |
| Mots-clés | `itinéraire,horaires,rer,tram,…` | 96 | 100 | 96 % |
| Texte promotionnel | `Itinéraires, prochains passages…` | 162 | 170 | 95 % |
| Description | `Metyro réunit tout ce qu'il faut…` | 1 743 | 4 000 | 44 % |
| What's New | — | 0 | 4 000 | non requis en 1.0 |

---

## Contrôles hors-ligne

| # | Contrôle | Sévérité | Champ | Détail |
|---|---|---|---|---|
| 1 | Champ sous-exploité | ❌ | nom | 6/30 — **24 caractères perdus dans le champ le plus fortement pondéré de l'App Store** |
| 2 | Mot-clé absent du titre | ❌ | nom | aucun terme de recherche dans le nom. Le mot-clé n°1 du marché (`métro paris`) n'est présent que dans le sous-titre |
| 3 | Intention de recherche erronée | ⚠️ | mots-clés | 5 des 12 mots-clés attirent une intention hors sujet — mesuré sur l'autocomplétion Apple FR (voir ci-dessous) |
| 4 | Caractères gaspillés | ⚠️ | mots-clés | `ile-de-france` (13 car.) ⇒ `ile,france` (10 car.) : Apple découpe déjà sur le tiret et ignore `de`. **3 caractères récupérables** |
| 5 | Doublon inter-champs | 💡 | mots-clés | aucun — `rer`, `tram`, `bus` ne sont dans ni le nom ni le sous-titre. Ce point est propre |
| 6 | Séparateurs | ✅ | mots-clés | virgules sans espace, pas de point-virgule ni de pipe. Conforme |
| 7 | Couverture en description | 💡 | description | `trafic`, `idf`, `navigation` absents de la description. Sans effet sur l'index iOS, mais l'utilisateur qui a cherché « trafic » ne retrouve pas son mot |
| 8 | Cross-locale | — | — | une seule locale, rien à comparer |
| 9 | App tags Apple | 💡 | — | aucun tag renvoyé par l'API : normal avant publication, à re-vérifier après la mise en ligne pour valider que le classement Apple correspond au positionnement |

### Détail du contrôle 3 — l'intention derrière les mots-clés actuels

Mesuré sur l'autocomplétion réelle de l'App Store français (`docs/aso/data/apple-hints-fr-*.txt`).
Ce que l'autocomplétion propose sur un terme, c'est ce que les gens cherchent réellement.

| Mot-clé actuel | Ce que l'App Store FR propose réellement | Verdict |
|---|---|---|
| `itinéraire` | itinéraire **vélo**, **course à pied**, **michelin**, **voiture**, **moto**, **à pied** | ⚠️ intention randonnée / voiture, pas transport en commun |
| `trafic` | trafic **rider**, trafic **racer**, trafic **maritime**, trafic **aérien**, trafic **routier** | ⚠️ jeux de voiture et suivi de navires |
| `tram` | tram **montpellier**, **bordeaux**, **strasbourg**, **nice**, **nantes** | ⚠️ toutes les villes sauf Paris |
| `gare` | gare **sncf**, **garena**, garer **voiture**, gare **parking** | ⚠️ moitié SNCF, moitié stationnement |
| `navigation` | (non proposé en tête) — l'espace est tenu par Waze et le GPS routier | ⚠️ intention voiture |
| `horaires` | horaire **prière**, horaire **marée**, horaire **bus** | ⚠️ dominé par les horaires de prière ; ne paie que combiné à `bus` / `métro` |
| `rer` | rer **paris**, rer **d**, rer **b** | ✅ propre et pertinent |
| `bus` | bus **simulator**, **busuu**, **business** | ⚠️ seul, il est mort ; combiné (`bus paris`, `horaire bus`) il est excellent |
| `transport` | transport **ile de france** ← 1ʳᵉ suggestion, transport **paris** | ✅ très pertinent |
| `idf` | idf **mobilite**, **idfm**, idf **transport**, idf **navigo** | ✅ pertinent et peu cher (3 car.) |
| `perturbation` | perturbation | ✅ terme réel mais coûteux (12 car.) |
| `ile-de-france` | ile de france **mobilite** | ✅ pertinent, mal orthographié pour l'index |

**Ce qui manque et qui a une vraie demande** : `transilien` (suggestion propre, seulement
3 résultats d'autocomplétion — faible concurrence), `plan` (`plan métro paris` est une
famille de requêtes entière), `prochain` (`prochain metro` est une suggestion réelle),
`station`, `ligne`, `commun` (`transport en commun paris`).

---

## Les cinq constats qui comptent

### 1. Le titre est le problème, et il est plus grave qu'il n'en a l'air ❌

`Metyro` occupe 6 caractères sur 30. Le nom de l'app est le champ **le plus fortement
pondéré** de l'index de recherche Apple. Metyro y met une marque que personne ne cherche
encore, et n'y met aucun mot que quelqu'un tape.

Ce n'est pas une opinion : c'est le comportement observable du marché. Sur la requête
`metro paris`, l'app classée n°1 devant l'Île-de-France Mobilités et Bonjour RATP est
`Métro Paris & RER` — 17 caractères, **zéro marque**, correspondance exacte pure, avec
13 914 avis contre 144 270 pour IDFM. Un titre en correspondance exacte bat l'autorité.

Et le format est une convention de catégorie, pas une prise de risque :

```
Transit • Horaires Bus & Métro     30/30
Métro Paris & Bus - HorairesMe     30/30
Mon Écran — Métros RER BUS & +     30/30
SNCF Connect: Trains & trajets     30/30
Métro de Paris et Itinéraires      29/30
Ma Ligne - Trafic Metro & RER      29/30
Moovit: Transports en commun       28/30
Tisséo : Métro, Tram, Bus          25/30
──────────────────────────────────────
Metyro                              6/30   ← nous
```

### 2. Zéro capture d'écran ❌ — et c'est aussi ce qui bloque la soumission

`asc validate` remonte trois erreurs bloquantes : pas de captures, pas de build attaché,
pas de coordonnées de review. Les captures sont la seule des trois qui soit aussi un
**facteur de classement** : Apple les indexe désormais sémantiquement, le texte incrusté
compte. Une page produit sans capture ne se classe pas et ne convertit pas.

C'est 15 % du score, à zéro, et c'est le premier travail à lancer parce que c'est le plus
long. Le dépôt a déjà ce qu'il faut : compétence `app-store-paper-designer`, recherche
`docs/research/app-store-iphone-screenshots-apple.md`.

### 3. Le champ mots-clés est plein mais mal ciblé ⚠️

96/100 caractères utilisés — bon réflexe. Mais cinq des douze termes ramènent une intention
hors sujet (tableau ci-dessus), et trois caractères partent dans `ile-de-france` là où
`ile,france` produit exactement le même index. Ce n'est pas un champ à remplir davantage,
c'est un champ à recomposer.

### 4. La description est bien écrite mais s'ouvre mal ⚠️

1 743 caractères d'un français juste et sobre, bien structuré. Deux réserves :

- **L'accroche.** Les 170 premiers caractères sont tout ce que l'utilisateur voit avant
  « plus ». Aujourd'hui : « Metyro réunit tout ce qu'il faut pour vos trajets en
  Île-de-France : itinéraires, prochains passages, perturbations et suivi en direct ».
  C'est un sommaire, pas une accroche. Aucun bénéfice, aucune scène.
- **Des promesses vraies absentes.** Le code fait Transilien, Vélib' (capacité et vélos
  disponibles) et les toilettes en station. La description n'en parle pas. Ce sont
  précisément les différenciateurs.

### 5. Une seule locale — opportunité réelle, mais bloquée en amont 💡

Paris est la première destination touristique mondiale et le store FR laisse déjà passer
des apps à titre anglais (`Paris Metro Map + Bus & RER`, `Paris Metro, RER & Offline Map`).
Une fiche `en-US` ouvrirait un jeu titre + sous-titre + mots-clés entièrement neuf.

**Mais l'app est monolingue française** : chaînes françaises en dur, aucun `.xcstrings`.
Localiser la fiche avant l'app, c'est promettre une app anglaise et livrer une app
française — mauvaise conversion, et motif de rejet possible. Cette opportunité est réelle
et se séquence **après** la localisation de l'app, pas avant.

---

## Gains immédiats (aujourd'hui)

1. **Réécrire le titre** en `Metyro : Métro Paris, RER, Bus` (30/30). Un champ, le plus
   pondéré, qui passe de 20 % à 100 % d'utilisation.
2. **Recomposer le champ mots-clés** autour de `transilien`, `plan`, `prochain`, `station`,
   `ligne`, `commun` et sortir `trafic`, `navigation`, `gare`, `tram` seul.
3. **Réécrire le sous-titre** pour qu'il complète le nouveau titre au lieu de le doubler —
   `Horaires et trafic temps réel` (29/30).
4. **Réécrire l'accroche** de la description : une scène, pas un sommaire.
5. **Ajouter Transilien, Vélib' et les toilettes** à la description — ce sont des
   fonctionnalités livrées et non vendues.

Champs exacts prêts à poser : `docs/aso/03-metadata.md`.

## Chantiers à fort impact (cette semaine)

1. **Produire les captures** — 6 à 8 visuels, texte incrusté porteur de mots-clés, les
   trois premiers vendant temps réel / langage naturel / Live Activity.
2. **Débloquer la soumission** — build attaché, coordonnées de review, App Privacy publiée.
3. **Trancher la question des marques tierces** (RATP, Navigo, Vélib', Transilien) :
   arbitrage documenté dans `docs/aso/02-keyword-research.md`.
4. **Poser les catégories** — primaire et secondaire ne sont pas renseignées sur l'app-info.

## Stratégique (ce mois-ci)

1. **Vidéo d'aperçu** — 5 % du score, à zéro, et la Live Activity se démontre mieux qu'elle
   ne se raconte.
2. **Amorcer les avis** — 15 % du score dépend d'une base d'avis. Une invitation à noter
   posée au bon moment (après un trajet suivi jusqu'au bout, pas au lancement).
3. **Localisation de l'app puis de la fiche** en anglais, pour ouvrir le marché touriste.
4. **Re-lire les app tags Apple** après publication, pour vérifier que le classement
   automatique d'Apple correspond au positionnement voulu.
5. **Rejouer cet audit tous les mois** — l'ASO n'est pas une opération ponctuelle.

---

## Comparaison concurrentielle

| | Titre util. | Sous-titre util. | Avis | Langage naturel | Live Activity | Accessibilité station |
|---|---|---|---|---|---|---|
| **Metyro (actuel)** | 20 % | 83 % | 0 | ✅ | ✅ | ✅ |
| **Metyro (proposé)** | 100 % | 97 % | 0 | ✅ | ✅ | ✅ |
| Île-de-France Mobilités | 77 % | 100 % | 144 270 | ❌ | ❌ | partiel |
| Citymapper | 33 % | 100 % | 190 510 | ❌ | ❌ | ❌ |
| Bonjour RATP | 40 % | 100 % | 59 762 | ❌ | ❌ | partiel |
| Transit | 100 % | 100 % | 95 030 | ❌ | ❌ | ❌ |
| Métro Paris & RER | 57 % | 83 % | 13 914 | ❌ | ❌ | ❌ |

Le tableau dit la stratégie : sur l'autorité, Metyro perd de trois ordres de grandeur et
perdra pendant des mois. Sur la correspondance de mots-clés et sur la différenciation
produit, Metyro peut gagner dès la première semaine — à condition d'arrêter de laisser
24 caractères vides dans le champ le plus important de la fiche.
