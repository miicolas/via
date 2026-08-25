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
