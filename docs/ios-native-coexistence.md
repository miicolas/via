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

Le flux NDJSON natif est versionné par `/v1`. Son schéma partagé côté serveur
est [`packages/contract/src/native-chat/schema.ts`](../packages/contract/src/native-chat/schema.ts).
Ses événements sont `text_delta { text }`, `itinerary { destination, journeys }`
et `finished`; une destination utilise la forme domaine Swift `{ kind, id,
name, context?, coordinate: { latitude, longitude } }`.

Les deux clients restent servis par le même backend. Les requêtes natives
portent les headers `x-via-client-platform: ios-native`,
`x-via-client-version` et `x-via-client-build`, afin de séparer les métriques
par plateforme, version et build sans inclure de recherche, coordonnées ou
identifiant anonyme dans les logs applicatifs.

Le trajet naturel (`POST /api/natural-journeys`) conserve une interface
domaine Swift typée, mais son adapter live utilise ponctuellement
`URLSession`: la version générée actuelle de Swift OpenAPI Generator ne
matérialise pas correctement les champs `nullable` issus de `anyOf` dans le
brouillon `resolve`, et risquerait de les supprimer. Cette compatibilité est
isolée dans `OpenAPITransitAPI` et devra être retirée après validation d’une
version corrigée du [générateur Apple](https://github.com/apple/swift-openapi-generator/issues/926).

## Contrats encore absents

L’audit du contrat actuel ne contient pas de route d’identité/session ni de
route Navigo. Le client natif ne simule donc pas une connexion : son adapter
`AuthenticationClient` expose explicitement l’état indisponible et l’écran
propose une continuation anonyme. De la même manière, `NavigoClient` expose
un état indisponible et le shell affiche un écran d’attente honnête.

Ces adapters sont les seams à remplacer quand les contrats backend seront
validés. Tant qu’ils restent indisponibles, aucun mot de passe, jeton ou titre
Navigo ne doit être stocké ou envoyé par le client natif.

Les recherches récentes natives sont stockées sous la clé versionnée
`via.recent-searches.v1` avec `UserDefaults`, dédupliquées et limitées à cinq
entrées. Lors du premier lancement du bundle de production `dev.via.app`,
`MigratingRecentSearchStore` lit en lecture seule l’ancienne base
`Documents/SQLite/ExpoSQLiteStorage` d’Expo, selon le stockage SQLite documenté
par [Expo SDK 57](https://docs.expo.dev/versions/v57.0.0/sdk/sqlite/), et importe la même valeur
`via.recent-searches.v1`, puis pose le marqueur
`via.recent-searches.expo-imported.v1`. La migration est idempotente, ignore une
base absente ou invalide et ne remplace jamais des recherches déjà présentes
dans le stockage natif. Le bundle interne `dev.via.app.native` ne partage pas ce
conteneur : la validation finale doit donc inclure une mise à jour réelle du
bundle App Store, pas seulement une installation côte à côte.

L'identité anonyme `via.anonymous-client-id` suit la même règle de continuité.
`ClientIdentityStore` lit d'abord la clé native du service `dev.via.app` ; si
elle n'existe pas encore, il relit les formes utilisées par Expo SecureStore
(`app:no-auth`, `app:auth`, puis `app`) avec le nom de clé encodé dans les
attributs Keychain `account` et `generic`, avant de recopier la valeur dans le
service natif. L'ancienne entrée Expo n'est pas supprimée : un retour arrière
reste possible. Cette lecture ne peut être validée que lors d'une mise à jour
du bundle de production `dev.via.app`, pas avec `dev.via.app.native`.

## Bascule locale et garde-fous

Les overrides ci-dessous sont volontairement disponibles uniquement dans les
configurations Debug et Staging. Un binaire Release ne peut pas sélectionner
les données de démonstration ni masquer silencieusement une tranche native.

| Override | Effet |
| --- | --- |
| `--via-demo` ou `VIA_DEMO_DATA=1` | Adapters déterministes pour les smoke tests |
| `--via-disable-chat` ou `VIA_FEATURE_CHAT=0` | Masque l’entrée chat |
| `--via-disable-classic-journeys` ou `VIA_FEATURE_CLASSIC_JOURNEYS=0` | Masque la planification classique |
| `--via-disable-natural-journeys` ou `VIA_FEATURE_NATURAL_JOURNEYS=0` | Masque la planification en langage naturel |
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
schéma Release. Staging conserve ce levier pour les validations internes et
utilise le bundle séparé `dev.via.app.staging`.

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

Le client iOS 26 s'abonne aussi à `MXMetricManager` pendant toute la durée de
l'application. Il compte les rapports MetricKit reçus dans la catégorie
`metrics`, sans sérialiser leur contenu, leurs coordonnées, leurs messages ou
un identifiant utilisateur. Les budgets réels restent à mesurer sur appareil
et TestFlight ; cette souscription prépare cette mesure sans créer un second
pipeline de télémétrie propriétaire.

La localisation standard est une session de premier plan : `MapFeatureModel`
appelle `stopUpdatingLocation()` lorsque la scène quitte l'état actif et
réactive la livraison au retour, sans déclarer de mode de localisation en
arrière-plan. Les coordonnées déjà reçues restent disponibles pour afficher
un état cohérent, mais aucun suivi continu n'est maintenu quand l'utilisateur
n'utilise plus la carte.

La fermeture de la sheet de chat annule également le stream en cours. La
session réseau ne reste donc pas attachée à une vue disparue, que l'utilisateur
ferme la sheet avec le bouton d'arrêt, le geste système ou l'ouverture du
détail d'itinéraire.

La typographie native embarque les mêmes graisses Archivo et Inter que le
client Expo. Les composants passent par `ViaFont` au lieu de répéter des noms
de police ; les appels `Font.custom(_:size:relativeTo:)` conservent la mise à
l'échelle Dynamic Type. Les fichiers de police et leurs licences OFL sont
versionnés dans `apps/ios/Via/Fonts`.

Le handle de la sheet expose aussi une valeur et une action ajustable à
VoiceOver : les gestes d'incrémentation et de décrémentation changent la
hauteur du panneau via la même transition que le drag tactile.

Le défilement automatique du chat respecte également le réglage système
« Réduire les animations » : il rejoint le dernier message sans transition
animée lorsque `accessibilityReduceMotion` est actif.

Le même réglage désactive l'animation de sélection des marqueurs de station ;
`accessibilityReduceTransparency` remplace le matériau translucide de la sheet
par une surface Via opaque.

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
