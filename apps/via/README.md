# Via iOS

Application SwiftUI native iPhone, iOS 26+, structurée en Clean MVVM par fonctionnalité.

## Construire une View

`AppDependencies` est l’unique composition root. Une View d’écran crée son ViewModel avec la factory correspondante, le conserve avec `@State`, puis rend son état exhaustif. Les Views ne doivent importer ni `OpenAPIRuntime`, ni `OpenAPIURLSession`, ni un DTO de `Shared/Networking`.

Les points d’entrée prêts à consommer sont :

- `NetworkViewModel` : carte ferrée, sélection de ligne et stations par tuiles ;
- `MapPresentationModel` : recherche classique et naturelle, géolocalisation, récents, planification et navigation de la feuille carte ;
- `DeparturesViewModel` : départs et polling suspendable ;
- `ChatViewModel` : conversation locale avec Apple Foundation Models, disponibilité exhaustive et itinéraire atomique ;
- `LocationAdapter` : seam de localisation orchestré par `MapPresentationModel`.

## Contrat API

```sh
bun run generate:ios-api
bun run check:openapi
```

La commande part du contrat TypeScript, produit les snapshots OpenAPI versionnés, puis régénère `GeneratedSources`. Le chat ne fait pas partie du contrat réseau iOS : Foundation Models génère la conversation sur l’appareil et appelle les modules de recherche et de trajet comme tools.

Le chat exige qu’Apple Intelligence et son modèle français soient disponibles. `ChatViewModel.State.unavailable` expose la raison directement à la future View ; les autres fonctionnalités restent disponibles sans Apple Intelligence.

Les URL se règlent dans `Configuration/*.xcconfig`. Une archive Release échoue tant que l’URL de production utilise le domaine `.invalid`.
