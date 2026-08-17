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

La recherche en langage naturel utilise Foundation Models sur l’appareil pour interpréter la demande et rédiger une réponse vérifiée. Le géocodage et le calcul d’itinéraire restent servis par `/api/search` et `/api/journeys`. Si le modèle local est indisponible ou échoue, l’app bascule silencieusement vers `/api/natural-journeys`.

Les raisons liées à Apple Intelligence ne sont présentées que si le chemin local et le chemin serveur échouent tous les deux. La recherche classique reste disponible indépendamment.

Les URL se règlent dans `Configuration/*.xcconfig`. Une archive Release échoue tant que l’URL de production utilise le domaine `.invalid`.
