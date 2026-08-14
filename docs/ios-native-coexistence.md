# Coexistence Expo / iOS natif

Le client SwiftUI vit dans `apps/ios` avec le bundle interne
`dev.via.app.native`. Le client Expo reste propriétaire de `apps/mobile` et de
son projet `ios/` généré. Pendant la coexistence, aucun des deux projets ne
réécrit les fichiers de l’autre.

## Contrats actifs

| Client | Transport | Contrats à préserver |
| --- | --- | --- |
| Expo | `/rpc` et `POST /ai/chat` | Client public de référence et hotfix |
| iOS natif | `/api` et `POST /ai/chat/v1` | OpenAPI généré, NDJSON chat |

Les deux clients restent servis par le même backend. Les requêtes natives
portent les headers `x-via-client-platform: ios-native`,
`x-via-client-version` et `x-via-client-build`, afin de séparer les métriques
par plateforme, version et build sans inclure de recherche, coordonnées ou
identifiant anonyme dans les logs applicatifs.

## Bascule locale et garde-fous

Les overrides ci-dessous sont volontairement disponibles uniquement dans la
configuration Debug. Un binaire Release ne peut pas sélectionner les données
de démonstration ni masquer silencieusement une tranche native.

| Override | Effet |
| --- | --- |
| `--via-demo` ou `VIA_DEMO_DATA=1` | Adapters déterministes pour les smoke tests |
| `--via-disable-chat` ou `VIA_FEATURE_CHAT=0` | Masque l’entrée chat |
| `--via-disable-classic-journeys` ou `VIA_FEATURE_CLASSIC_JOURNEYS=0` | Masque la planification classique |
| `--via-diagnostics` ou `VIA_DIAGNOSTICS=1` | Active les logs réseau détaillés |
| `VIA_API_URL=https://...` | Change l’origine API après validation HTTP(S) |

Exemple de lancement UI déterministe :

```sh
xcodebuild \
  -project apps/ios/Via.xcodeproj \
  -scheme Via \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -derivedDataPath apps/ios/.derived-openapi \
  CODE_SIGNING_ALLOWED=NO \
  -disableAutomaticPackageResolution \
  build
```

Le smoke test UI ajoute `--via-demo` dans
`apps/ios/ViaUITests/ViaUITests.swift`; il ne doit jamais être ajouté au
schéma Release.

## Journalisation

Via utilise Unified Logging avec le subsystem `dev.via.app` et les catégories
`app`, `network` et `chat`. Les logs détaillés restent désactivés par défaut ;
les erreurs réseau journalisent uniquement une opération, un chemin fixe et
une classe d’erreur normalisée.

Pour observer une session de diagnostic :

```sh
log stream --level debug --predicate 'subsystem == "dev.via.app"'
```

Une recherche utilisateur, un identifiant de station, une coordonnée, un
token ou l’identifiant Keychain ne doit pas être ajouté à `ViaLogger`.

## Critères de cutover

Le remplacement du bundle public est autorisé seulement lorsque tous les
points suivants sont vérifiés et attachés au build candidat :

1. Le build Expo de référence est reproductible, avec une matrice de parité
   possédant un résultat attendu pour chaque état carte, recherche, départs,
   trajet, clarification et chat.
2. La suite native couvre les mêmes parcours fonctionnels et les écarts
   visuels expliqués sur la matrice d’appareils retenue.
3. Les taux de succès, latences p50/p95, time-to-first-token du chat,
   crash-free sessions, mémoire carte, lancement et hitches restent dans les
   budgets mesurés du build Expo de référence.
4. Une mise à jour native est installée par-dessus un conteneur Expo
   représentatif ; les recherches récentes, le Keychain et les préférences
   sont relus sans perte critique.
5. Le backend reste compatible avec le client Expo public et le build natif
   précédent ; les deux endpoints chat et les deux transports ordinaires sont
   testés ensemble.
6. Les overrides Debug ont été exercés, les logs de cohorte sont lisibles et
   un retour arrière backend est possible sans publier de nouveau client.

Après le cutover, la chaîne Expo et sa branche de hotfix restent conservées
jusqu’à ce qu’aucune version Expo supportée ne génère encore de trafic et que
plusieurs releases natives fiables aient été observées. La suppression
d’Expo est alors une PR dédiée, réversible par Git.

Références Apple utilisées pour cette implémentation :

- [ProcessInfo](https://developer.apple.com/documentation/foundation/processinfo)
- [Logger et Unified Logging](https://developer.apple.com/documentation/os/logger)
