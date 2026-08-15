# Récapitulatif de la migration iOS 26

Date : 15 août 2026  
Branche : `codex/ios-26-migration`  
Dernier commit : `b07d295 build(ios): embed the release API origin`

## Objectif et état général

Un client iOS natif SwiftUI est maintenant construit dans `apps/ios`, en
parallèle du client Expo existant. Le projet cible iOS 26, utilise Swift 6
avec la vérification stricte de concurrence et possède son propre projet
Xcode, ses tests et son package de contrat API.

Le socle natif est opérationnel en Debug/Staging avec des adapters de démonstration
déterministes. Il ne faut pas encore considérer le projet comme prêt pour une
distribution App Store : les dépendances de production listées plus bas ne
sont pas disponibles ou n'ont pas encore été validées sur appareil.

## Ce qui a été fait

- Création du projet Xcode autonome `apps/ios/Via.xcodeproj`, du schéma partagé
  `Via`, des configurations Debug, Staging et Release, et des bundle IDs
  `dev.via.app.native`, `dev.via.app.staging` et `dev.via.app`.
- Configuration iOS 26, Swift 6 strict concurrency, composition des
  dépendances, routeur de valeurs et shell SwiftUI.
- Création du package local `ViaAPIContract` depuis le contrat OpenAPI.
  Les types générés restent derrière des adapters ; les vues ne connaissent
  ni les DTO générés ni les URLs.
- Portage des parcours carte, recherche, stations, départs, lignes, trajets
  classiques, trajets en langage naturel, clarification, détail de trajet et
  carte MapKit.
- Ajout du chat natif en NDJSON sur `/ai/chat/v1`, avec cancellation quand la
  sheet est fermée. Le client Expo continue d'utiliser `/ai/chat`.
- Ajout de la localisation de premier plan, des recherches récentes, de la
  continuité de l'identité anonyme Keychain et de la migration de stockage
  depuis Expo quand le bundle de production est mis à jour.
- Ajout des adapters Auth et Navigo explicitement indisponibles tant que les
  contrats backend n'existent pas. Aucun faux endpoint, mot de passe, jeton ou
  titre Navigo n'est simulé.
- Ajout des overrides Debug/Staging : `--via-demo`, désactivation des features,
  diagnostics et `VIA_API_URL`. Les overrides locaux ne sont pas actifs en
  Release.
- Ajout de la validation de build Release : une origine API HTTP(S) réelle doit
  être injectée avec `VIA_API_URL`; un archive Release sans cette valeur échoue.
- Mise en place de la typographie Via (Archivo/Inter), des composants réutilisables,
  de la gestion de Réduire les animations/Réduire la transparence et d'un handle
  de sheet ajustable à VoiceOver.
- Documentation de la coexistence Expo/native, de l'architecture, des seams,
  de la persistance et des critères de cutover dans `docs/`.

## Validations déjà passées

- Tests unitaires Swift `ViaTests` : Debug et Staging.
- Tests UI `ViaUITests` : Debug et Staging, avec les adapters demo.
- API : `bun --cwd apps/api test` — 114 tests réussis, 0 échec,
  201 attentes, 31 fichiers.
- Typecheck API et contrat, build du package Swift, snapshot OpenAPI.
- Builds Debug, Staging et Release avec URL API injectée.
- Vérification négative : un build Release sans `VIA_API_URL` échoue
  volontairement.

## Ce qui reste avant une vraie livraison

1. Obtenir et valider les contrats backend réels pour Auth et Navigo, puis
   remplacer leurs adapters indisponibles.
2. Fournir l'origine API de production, la signature Apple, les secrets de
   distribution et un pipeline TestFlight/App Store.
3. Tester une mise à jour du bundle public `dev.via.app` par-dessus une
   installation Expo réelle : recherches récentes, Keychain et préférences.
4. Faire la matrice de parité visuelle/fonctionnelle avec Expo et les essais
   sur appareils iOS réels.
5. Mesurer les budgets lancement, mémoire carte, hitches, latences p50/p95,
   time-to-first-token et crash-free sessions ; MetricKit est seulement
   branché, pas encore validé sur appareil/TestFlight.
6. Décider puis exécuter le cutover ; la suppression d'Expo doit rester une PR
   séparée et réversible.

## Point de reprise immédiat

L'audit a identifié un cas à traiter : un deep-link `via://chat` peut encore
  contourner le feature flag Chat, même si le bouton d'entrée est masqué.
Le premier lot de correction a été retiré avant ce récapitulatif car son test
UI `XCUIApplication.open(_:)` bloquait le runner. Il faut reprendre ce point
avec une politique pure réutilisable (`AppRoutePolicy`), un test unitaire et
un test UI qui ne dépend pas du lancement d'un deep-link externe.

Avant de poursuivre, vérifier :

```sh
git status --short --branch
git log --oneline --decorate -20
```

La règle de travail reste : une seam réelle, des composants réutilisables,
aucune duplication de logique et un petit commit vérifié par lot.
