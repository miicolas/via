# Via iOS

Application SwiftUI native iPhone, iOS 26+, structurée en Clean MVVM par fonctionnalité.

## Construire une View

`AppDependencies` est l’unique composition root. Une View d’écran crée son ViewModel avec la factory correspondante, le conserve avec `@State`, puis rend son état exhaustif. Les Views ne doivent importer ni `OpenAPIRuntime`, ni `OpenAPIURLSession`, ni un DTO de `Shared/Networking`.

Les points d’entrée prêts à consommer sont :

- `NetworkViewModel` : carte ferrée, sélection de ligne et stations par tuiles ;
- `MapPresentationModel` : recherche classique et naturelle, géolocalisation, récents, planification et navigation de la feuille carte ;
- `DeparturesViewModel` : départs et polling suspendable ;
- `NaturalIntentParsing` : compréhension locale Foundation Models, utilisée en priorité par la recherche en langage naturel ;
- `LocationAdapter` : seam de localisation orchestré par `MapPresentationModel`.

## Contrat API

```sh
bun run generate:ios-api
bun run check:openapi
```

La commande part du contrat TypeScript, produit les snapshots OpenAPI versionnés, puis régénère `GeneratedSources`.

La recherche en langage naturel utilise Foundation Models sur l’appareil d’abord pour extraire une demande structurée en français. Le modèle ne rédige aucune réponse. Le géocodage et le calcul d’itinéraire restent servis par `/api/search` et `/api/journeys`.

Quand le modèle local est indisponible ou échoue pour une raison système, la soumission initiale passe par `POST /api/natural-journeys` (agent serveur borné, voir ADR-0004) ; les clarifications restent traitées sur l’appareil, et une phrase refusée par le modèle local n’est jamais transmise au serveur.

Les URL se règlent dans `Configuration/*.xcconfig`. Une archive Release échoue tant que l’URL de production utilise le domaine `.invalid`.

## Extensions

Trois cibles composent l’app : `via` (l’application), `JourneyActivityExtension` (l’activité en direct pendant un trajet) et `ViaWidgetExtension` (les widgets et les boutons Contrôle).

`ViaWidgetExtension` fournit deux widgets — **Trajet favori** et **Lignes favorites**, disponibles en écran d’accueil et en écran verrouillé — et trois boutons pour l’écran verrouillé et le centre de contrôle : lancer un trajet favori, ouvrir l’état des lignes, ouvrir la recherche d’itinéraire.

L’extension ne lie ni le domaine de l’app ni son client OpenAPI. Ce qu’elle dessine traverse le groupe d’applications `group.dev.via.app` :

- l’app publie un instantané des favoris (`ViaWidgetShared/WidgetFavoritesSnapshot.swift`) et ne demande un rechargement des timelines que lorsque ce que le widget dessine a bougé ;
- un bouton de contrôle ne peut pas ouvrir une URL : il exécute `OpenViaRouteIntent`, qui dépose la route dans le même groupe et demande l’ouverture de l’app, laquelle la consomme au premier passage au premier plan ;
- le widget des lignes rafraîchit lui-même les conditions par un `GET /lines/statuses` portant la clé client de première partie (ADR-0003), et retombe sur l’instantané publié quand l’API est injoignable.

`ViaWidgetShared` est compilé dans l’app **et** dans l’extension ; `ViaWidgetLink` y construit les liens `via://` que `MapRoute` analyse côté app, et `ViaWidgetLinkTests` fait l’aller-retour entre les deux.

### Provisioning

Le groupe d’applications `group.dev.via.app` doit exister sur le portail développeur et être coché sur les App IDs `dev.via.app` **et** `dev.via.app.Widgets`. Sans lui, l’app et les widgets démarrent quand même : l’instantané est simplement introuvable et chaque widget affiche son état vide.
