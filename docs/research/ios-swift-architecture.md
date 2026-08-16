# Architecture d'une app iOS moderne en SwiftUI

## Faits observés dans les sources Apple

- Une app SwiftUI démarre avec une structure `App`, une `Scene` (`WindowGroup` sur iOS) et une hiérarchie de `View`.
  Source : [Exploring the structure of a SwiftUI app](https://developer.apple.com/tutorials/swiftui-concepts/exploring-the-structure-of-a-swiftui-app).
- Apple sépare le modèle de données de l'interface pour améliorer modularité, testabilité et lisibilité. Avec iOS 17 et plus, `@Observable` est le mécanisme moderne ; pour une cible antérieure à iOS 17, Apple documente encore `ObservableObject`.
  Sources : [Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app), [Monitoring data changes in your app](https://developer.apple.com/documentation/swiftui/monitoring-data-changes-in-your-app).
- SwiftUI permet de placer le modèle source de vérité dans `@State` au niveau de l'app ou d'une scène, puis de le partager dans la hiérarchie via l'environnement.
  Source : [Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app).
- La navigation programmatique et la restauration d'état se modélisent avec `NavigationStack`, un `path` ou `NavigationPath`, et des destinations basées sur des valeurs légères.
  Sources : [NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack), [Understanding the navigation stack](https://developer.apple.com/documentation/swiftui/understanding-the-navigation-stack).
- Les Swift Packages locaux sont un outil de modularisation et de réutilisation, pas une obligation de découper chaque couche de l'application.
  Source : [Swift packages](https://developer.apple.com/documentation/Xcode/swift-packages).
- L'exemple officiel [Food Truck](https://github.com/apple/sample-food-truck) utilise un projet Xcode avec une cible d'app, des dossiers `App` et `Configuration`, un package local `FoodTruckKit` et une cible `Widgets`. Il ne crée pas un package séparé pour chaque couche métier.
- MapKit fournit une API SwiftUI avec marqueurs, annotations et `MapPolyline`. Pour un contrôle plus fin, une vue UIKit peut être intégrée à SwiftUI via `UIViewRepresentable`.
  Sources : [MapKit for SwiftUI](https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui), [UIViewRepresentable](https://developer.apple.com/documentation/swiftui/uiviewrepresentable).
- `URLSession` fournit les appels `async` et les flux `AsyncBytes`, adaptés à un client REST et au streaming du chat.
  Sources : [URLSession](https://developer.apple.com/documentation/foundation/urlsession), [URLSession.AsyncBytes](https://developer.apple.com/documentation/foundation/urlsession/asyncbytes).
- XCTest reste adapté aux tests UI avec XCUIAutomation ; Swift Testing peut être utilisé pour les nouveaux tests unitaires sur les versions récentes de Xcode.
  Source : [XCTest](https://developer.apple.com/documentation/xctest).

## Inférence pour Via

La cible la plus idiomatique n'est donc pas une collection de packages `Domain`, `Networking`, `Platform`, etc. Elle devrait être une app Xcode iOS unique, organisée par fonctionnalité, avec quelques dossiers transversaux et éventuellement un seul package local si une frontière de compilation ou de réutilisation le justifie.

```text
Via.xcodeproj
Via/
  App/
    ViaApp.swift
    AppDependencies.swift
    AppRouter.swift
  DesignSystem/
    Theme/
    Components/
    Resources/
  Features/
    Map/
    Search/
    Departures/
    Journeys/
    Chat/
    Onboarding/
    Authentication/
  Services/
    API/
    Location/
    Persistence/
  Resources/
ViaTests/
ViaUITests/
```

Chaque fonctionnalité possède ses vues SwiftUI, son modèle observable et sa logique de présentation. La racine de l'app compose les dépendances concrètes et les injecte ; les fonctionnalités ne construisent pas elles-mêmes leur client réseau, leur localisation ou leur stockage.

Pour Via, le backend et le contrat existants restent la source de vérité. Le client généré s'appuie sur `URLSession`, avec des adapters dédiés pour la localisation et la persistance. La carte utilise MapKit SwiftUI ; `MKMapView` via `UIViewRepresentable` reste une seam disponible si la parité visuelle ou le contrôle de caméra l'exige.

## Décision de plateforme

L'application cible iOS 26 et Swift 6 avec la vérification stricte de concurrence. Les modèles de présentation utilisent Observation (`@Observable`) et sont isolés sur le main actor lorsqu'ils pilotent l'interface.
