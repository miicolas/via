# App Marketing Context — Metyro

> Document de référence pour toutes les compétences ASO (`aso-audit`, `keyword-research`,
> `metadata-optimization`, `screenshot-optimization`, `localization`, …).
> Reconstruit le 25/08/2026 à partir du dépôt et de l'App Store Connect API.
> Les lignes marquées **(à confirmer)** sont des hypothèses, pas des faits vérifiés.

## App Overview

- **App Name:** Metyro
- **App ID (Apple):** 6801259695
- **Bundle ID:** `dev.via.app` (le bundle id ne change jamais, même si la marque change)
- **SKU:** via
- **App ID (Google Play):** aucun — iOS uniquement, et c'est un choix (`AGENTS.md`)
- **Category:** Voyages (à confirmer — aucune catégorie n'est encore posée sur l'app-info)
- **Secondary Category:** Navigation (à confirmer)
- **Platform:** iOS 26+, SwiftUI, Swift 6
- **Price Model:** Gratuit (à confirmer)
- **Launch Date:** pas encore lancée — version 1.0 en `PREPARE_FOR_SUBMISSION`
- **Current Version:** 1.0 (version id `d49f0694-5979-418c-8645-83286bcb50fe`)
- **Primary Locale:** fr-FR — seule locale existante

## Value Proposition

- **Problem:** à Paris, savoir *maintenant* dans combien de minutes passe le prochain
  métro, si la ligne est perturbée, et par où passer si elle l'est. Les apps existantes
  répondent à la question en trois écrans et deux menus.
- **Target Audience:** l'usager quotidien d'Île-de-France sur iPhone — trajet domicile /
  travail, décision prise sur le quai ou dans la rue, en quelques secondes. Secondairement
  les voyageurs à mobilité réduite (itinéraires fauteuil, ascenseurs, accès de plain-pied)
  et les touristes (non adressés tant que l'app est monolingue française).
- **Unique Differentiator:**
  1. **Langage naturel local** — « Gare de Lyon avant 18 h » compris par Apple Intelligence,
     traité sur l'appareil. Aucun concurrent du top 10 FR ne le fait.
  2. **Live Activity de trajet** — prochain arrêt, correspondance et heure d'arrivée sur
     l'écran verrouillé, sans rouvrir l'app.
  3. **Design iOS 26 natif** — Liquid Glass, contrôles système, tout en symboles SF.
     Le peloton concurrent est majoritairement multiplateforme et daté.
  4. **Accessibilité de premier plan** — itinéraires fauteuil, ascenseurs, toilettes,
     affluence signalée par la communauté.
  5. **Vélib' intégré** au même endroit que le transport lourd.
- **Elevator Pitch:** Metyro dit dans combien de minutes passe votre prochain métro, et
  quoi faire quand la ligne lâche — en une phrase que vous écrivez comme vous la pensez.

## Competitors

Relevés le 25/08/2026 sur l'App Store français (titre + sous-titre réels, notes réelles).
Données brutes : `docs/aso/data/competitor-metadata-fr.txt` et `app-store-serp-fr.txt`.

| App | ID | Titre (car.) | Sous-titre (car.) | Note / avis |
|---|---|---|---|---|
| Île-de-France Mobilités | 484527651 | `Île-de-France Mobilités` (23) | `Appli Officielle Transport IDF` (30) | 4,7 / 144 270 |
| Citymapper | 469463298 | `Citymapper` (10) | `Itinéraires Bus, Métro, RER &+` (30) | 4,8 / 190 510 |
| Bonjour RATP | 507107090 | `Bonjour RATP` (12) | `Métro, RER, Transilien, Navigo` (30) | 4,7 / 59 762 |
| Transit | 498151501 | `Transit • Horaires Bus & Métro` (30) | `Paris RATP, Lyon TCL, TBM, RTM` (30) | 4,6 / 95 030 |
| Moovit | 498477945 | `Moovit: Transports en commun` (28) | `Métro, Bus, Train horaires` (26) | 4,6 / 25 194 |
| Métro Paris & RER | 1296797383 | `Métro Paris & RER` (17) | `Plan du Métro, RER et Bus` (25) | 4,6 / 13 914 |
| Métro de Paris et Itinéraires | 527534137 | `Métro de Paris et Itinéraires` (29) | `Plan réseau & itinéraires` (25) | 4,4 / 16 106 |
| Métro Paris & Bus - HorairesMe | 575814291 | `Métro Paris & Bus - HorairesMe` (30) | `Horaire des prochains passages` (30) | 4,4 / 8 186 |
| Mon Écran — Métros RER BUS & + | 1326558707 | `Mon Écran — Métros RER BUS & +` (30) | `Transports parisien en direct` (29) | 4,2 / 374 |
| Ma Ligne - Trafic Metro & RER | 6444736703 | `Ma Ligne - Trafic Metro & RER` (29) | `Infos RATP, RER & Transilien` (28) | 4,0 / 56 |

**Ce qu'ils font bien :** ils remplissent le titre. 6 des 10 utilisent 28–30 caractères,
et 9 sur 10 remplissent le sous-titre à 25–30. Le titre le mieux classé sur « metro paris »
n'a même pas de marque : `Métro Paris & RER`, correspondance exacte pure.

**Où ils sont faibles :** aucun ne fait de langage naturel, aucun n'a de Live Activity de
trajet, aucun n'est un vrai design iOS récent. Les deux applis officielles (IDFM, Bonjour
RATP) sont lourdes ; Citymapper et Transit sont génériques mondiaux et ne connaissent pas
l'accessibilité station par station.

**Mur d'autorité :** le top 5 pèse entre 25 000 et 190 000 avis. Metyro en aura zéro au
lancement. Aucune correspondance de mot-clé ne compensera cela sur les requêtes de tête à
court terme — la stratégie doit viser la longue traîne et les combinaisons.

## Current ASO State (au 25/08/2026, avant refonte)

- **Title:** `Metyro` — 6 / 30 caractères
- **Subtitle:** `Métro Paris en temps réel` — 25 / 30
- **Keyword Field:** `itinéraire,horaires,rer,tram,bus,trafic,perturbation,transport,idf,ile-de-france,navigation,gare` — 96 / 100
- **Promotional Text:** 162 / 170
- **Description:** 1 743 / 4 000
- **Screenshots:** aucune (bloque la soumission)
- **App Preview:** aucune
- **Rating:** — (jamais publiée)
- **Ranked Keywords:** — (jamais publiée)
- **App Tags Apple:** aucun

## Goals

*(à confirmer avec Nicolas — objectifs posés par défaut pour un lancement mono-marché)*

1. **Lancer** — 1.0 soumise et approuvée : captures, build, coordonnées de review, App Privacy.
2. **Se rendre indexable** — être trouvable sur les familles « métro paris », « plan métro
   paris », « horaire bus », « trafic métro », « transilien » dans les 30 jours suivant la mise
   en ligne.
3. **Convertir** — taux de conversion page produit au-dessus de la médiane catégorie Voyages,
   porté par des captures qui montrent le temps réel et la Live Activity.

## Resources

- **Budget:** aucun budget d'acquisition posé (à confirmer) — l'ASO organique est le levier.
- **Team:** solo + agents.
- **Tools:** `asc` CLI (App Store Connect API, profil « Via CLI » authentifié),
  compétences ASO Skills, compétences `asc-*`, `app-store-paper-designer` pour les captures.
- **Constraints:**
  - App **monolingue française** : pas de `.xcstrings`, chaînes françaises en dur. Toute
    localisation de fiche vers une autre langue crée un décalage app / fiche.
  - Aucune donnée de volume de recherche payante (Astro / Appeeky MCP non connectés) : la
    recherche de mots-clés s'appuie sur l'autocomplétion Apple réelle et les SERP réelles.
  - Marques tierces (RATP, Navigo, Vélib', Transilien, SNCF) : décision non tranchée,
    voir `docs/aso/02-keyword-research.md`.

## Markets

- **Primary:** France (storefront 143442), Île-de-France
- **Secondary:** aucun pour l'instant — voir la note de séquencement dans `docs/aso/01-audit.md`
- **Languages:** français uniquement (app et fiche)

## Fonctionnalités vérifiées dans le code

Ce qui suit a été vérifié dans `apps/via/via/` — toute promesse de fiche doit s'y adosser.

| Promesse | Vérifié |
|---|---|
| Métro, RER, Transilien, tramway, bus | `Features/Network` — les cinq modes sont modélisés |
| Prochains passages temps réel vs théorique | `Features/Departures` |
| Itinéraires, partir après / arriver avant | `Features/Journeys` |
| Langage naturel + Apple Intelligence sur l'appareil | `Features/NaturalJourneys` |
| Live Activity de trajet | `Features/ActiveJourney` |
| Carte du réseau, lignes, stations | `Features/Map`, `Features/Lines` |
| Vélib' : stations, capacité, disponibilité | `BikeStationDTO`, couche carte opt-in |
| Accessibilité : ascenseurs, plain-pied, toilettes | `StationDetailView`, `StationOverview` |
| Affluence signalée par les voyageurs | `Features/Reports` |
| Favoris, rappels / notifications | `Features/Stations`, `Features/Notifications` |
