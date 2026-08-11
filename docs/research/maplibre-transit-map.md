# MapLibre pour la carte de transport iOS

Date de vérification : 11 août 2026.

## Conclusion

`@maplibre/maplibre-react-native` v11 est une bonne alternative à `expo-maps` pour la carte de transport de Via. Le moteur rend le fond, le tracé et les stations dans la même scène vectorielle native et permet de calculer la taille et l'opacité des stations directement depuis le zoom fractionnaire. Cela évite le cycle actuel « événement caméra → état React → nouveau rayon », qui explique le changement de taille au relâchement du geste.

La recommandation est :

- MapLibre React Native v11 ;
- un fond OpenFreeMap Positron personnalisé sans aucune couche `symbol` ;
- une `GeoJSONSource` contenant la `LineString` GTFS et les 25 stations ;
- trois `Layer` MapLibre : liseré, ligne et stations ;
- rayon et opacité des stations pilotés par des expressions `interpolate` sur `zoom`, sans écouter les événements caméra et sans `setState` pendant le geste.

## Compatibilité avec le projet

Le projet utilise Expo SDK 57 et React Native 0.86.2. Expo indique que SDK 55 et suivants fonctionnent exclusivement avec la New Architecture ; elle ne peut plus être désactivée. [Expo — React Native's New Architecture](https://docs.expo.dev/guides/new-architecture/)

MapLibre React Native v11 est précisément la première version exclusivement New Architecture. Sa documentation demande React Native `>= 0.80.0`, et le manifeste publié de la version actuelle v11.3.6 déclare `react-native >= 0.80.0`, React `>= 19.1.0` et `@expo/config-plugins >= 54.0.0`. Les versions du projet entrent donc dans les plages officiellement déclarées. [MapLibre — Getting Started](https://maplibre.org/maplibre-react-native/docs/setup/getting-started/), [manifeste officiel v11.3.6](https://github.com/maplibre/maplibre-react-native/blob/v11.3.6/package/package.json), [release officielle v11.3.6](https://github.com/maplibre/maplibre-react-native/releases/tag/v11.3.6)

Nuance : le dépôt de MapLibre développe actuellement v11 avec React Native 0.85.3, même si la peer dependency accepte 0.86. Le build iOS Expo 57 doit donc être validé dans une branche/prototype avant de supprimer `expo-maps`. [manifeste officiel v11.3.6](https://github.com/maplibre/maplibre-react-native/blob/v11.3.6/package/package.json)

### Installation Expo

MapLibre fournit un config plugin Expo officiel : installation par `npx expo install @maplibre/maplibre-react-native`, ajout de `"@maplibre/maplibre-react-native"` à `expo.plugins`, puis reconstruction native. Le plugin ajoute notamment le hook CocoaPods requis par MapLibre Native sur iOS. La bibliothèque n'est pas utilisable dans Expo Go ; il faut le dev build déjà employé par le projet. [MapLibre — Expo Setup](https://maplibre.org/maplibre-react-native/docs/setup/expo/)

## API à utiliser en v11

Les noms `ShapeSource`, `LineLayer` et `CircleLayer` appartiennent à l'API v10. En v11 :

- `ShapeSource` devient `GeoJSONSource` ;
- les composants spécialisés `LineLayer`, `CircleLayer`, etc. sont consolidés dans `Layer` avec `type="line"` ou `type="circle"` ;
- les styles utilisent les propriétés officielles kebab-case de la MapLibre Style Specification dans `paint` et `layout`.

[MapLibre — migration vers v11](https://maplibre.org/maplibre-react-native/docs/setup/migrations/v11/)

`GeoJSONSource` accepte directement un objet GeoJSON et des `Layer` enfants. [MapLibre — GeoJSONSource](https://maplibre.org/maplibre-react-native/docs/components/sources/geo-json-source/)

Schéma de rendu proposé (illustratif, pas encore intégré) :

```tsx
<Map mapStyle={labelFreeStyle}>
  <Camera initialViewState={{ center: [2.34, 48.86], zoom: 11 }} />

  <GeoJSONSource id="metro-1" data={metro1GeoJSON}>
    <Layer
      id="metro-1-casing"
      type="line"
      filter={["==", ["geometry-type"], "LineString"]}
      layout={{ "line-cap": "round", "line-join": "round" }}
      paint={{ "line-color": "rgba(255,255,255,0.88)", "line-width": 4.25 }}
    />
    <Layer
      id="metro-1-line"
      type="line"
      filter={["==", ["geometry-type"], "LineString"]}
      layout={{ "line-cap": "round", "line-join": "round" }}
      paint={{ "line-color": "#E5AC00", "line-width": 2.5 }}
    />
    <Layer
      id="metro-1-stations"
      type="circle"
      filter={["==", ["geometry-type"], "Point"]}
      paint={{
        "circle-color": "#E5AC00",
        "circle-radius": [
          "interpolate", ["linear"], ["zoom"],
          10.8, 1.5,
          12.0, 2.35,
          16.0, 2.75,
        ],
        "circle-opacity": [
          "interpolate", ["linear"], ["zoom"],
          10.8, 0,
          11.4, 0,
          12.1, 1,
        ],
        "circle-pitch-scale": "viewport",
      }}
    />
  </GeoJSONSource>
</Map>
```

Les coordonnées GeoJSON doivent rester dans l'ordre `[longitude, latitude]`.

## Pourquoi l'apparition sera fluide

La MapLibre Style Specification définit les expressions caméra basées sur `['zoom']`. Une propriété `paint` est réévaluée à chaque variation fractionnaire du zoom, et non uniquement aux niveaux entiers. L'exemple officiel applique exactement `interpolate(linear, zoom, ...)` à `circle-radius`. [MapLibre Style Spec — camera expressions](https://maplibre.org/maplibre-style-spec/expressions/#camera-expressions)

`circle-radius` est exprimé en pixels, accepte `interpolate` et est disponible dans MapLibre Native iOS ; `circle-opacity` accepte également `interpolate`. [MapLibre Style Spec — Circle](https://maplibre.org/maplibre-style-spec/layers/#circle)

Conséquences :

- les points deviennent progressivement plus petits et transparents pendant le pincement ;
- il n'y a aucun seuil React qui monte/démonte 25 vues ;
- il n'y a pas de valeur arrondie corrigée par un dernier événement lorsque le doigt est relâché ;
- le rayon reste un rayon écran. Avec `circle-pitch-scale: "viewport"`, il ne varie pas selon la distance apparente si la carte est inclinée.

Il faut éviter `minzoom` pour cet effet : cette propriété masque la couche sous un seuil franc. Une interpolation d'opacité sur une plage de zoom produit le fade souhaité. `minzoom` peut rester une optimisation très basse, loin de la zone de transition. [MapLibre Style Spec — propriétés de Layer](https://maplibre.org/maplibre-style-spec/layers/#layer-properties)

## Fond de carte sans indications

OpenFreeMap confirme que ses styles fonctionnent avec MapLibre Native sur mobile et qu'ils peuvent être personnalisés pour retirer labels et POI. Un style personnalisé doit ensuite être fourni à MapLibre. [OpenFreeMap — Quick Start, Mobile Apps et Custom styles](https://openfreemap.org/quick_start/)

Point de départ recommandé : Positron, déjà conçu comme le style OpenFreeMap le plus épuré et sans POI. [OpenFreeMap Styles](https://github.com/hyperknot/openfreemap-styles)

Pour obtenir « uniquement la carte » :

1. prendre le JSON Positron officiel ;
2. supprimer toutes les couches dont `type` vaut `symbol` — dans la spécification MapLibre, une couche `symbol` porte les icônes et textes ;
3. supprimer aussi les couches de transport du fond que l'on ne veut pas voir, tout en conservant eau, parcs, bâtiments et voirie ;
4. conserver les attributions OpenFreeMap/OpenMapTiles/OpenStreetMap ;
5. versionner ce style avec l'app ou le servir depuis l'API Via afin que son rendu ne change pas à distance.

Le composant `Map` accepte soit une URL, soit un objet `StyleSpecification`, donc un JSON versionné dans l'application est techniquement possible. [MapLibre React Native — Map](https://maplibre.org/maplibre-react-native/docs/components/map/)

## Comparaison rapide

### `react-native-maps`

Ce choix ne résout pas le besoin principal en iOS Apple-only : sans provider Google, il repose encore sur MapKit. Sa documentation précise que le style personnalisé est une fonctionnalité Google Maps uniquement et que `mapType="none"` n'est pas disponible avec MapKit. [react-native-maps — API MapView](https://github.com/react-native-maps/react-native-maps/blob/master/docs/mapview.md), [README officiel](https://github.com/react-native-maps/react-native-maps)

Il est compatible Fabric à partir de 1.26.1 pour React Native `>= 0.81.1`, mais il ne donne pas la maîtrise vectorielle du fond recherchée ici. [react-native-maps — README, compatibility](https://github.com/react-native-maps/react-native-maps)

### Mapbox (`@rnmapbox/maps`)

Mapbox propose les sources, couches et expressions nécessaires, mais exige un compte/token Mapbox et introduit une dépendance fournisseur. Sa documentation officielle annonce React Native `0.79+`, Expo hors Expo Go, ainsi que `ShapeSource`, `LineLayer` et `CircleLayer`. [rnmapbox/maps — dépôt officiel](https://github.com/rnmapbox/maps)

Pour cette application, MapLibre offre le même modèle vectoriel utile sans imposer Mapbox, avec un fond OpenStreetMap/OpenFreeMap personnalisable. C'est donc le meilleur premier prototype.

## Plan de validation recommandé

1. Créer une branche de prototype et installer MapLibre v11 avec son config plugin.
2. Reconstruire le dev client iOS Expo 57.
3. Charger une copie locale de Positron sans couches `symbol`.
4. Réutiliser exactement le GeoJSON déjà renvoyé par `/api/routes/IDFM:C01371/map`, en convertissant les coordonnées en `[longitude, latitude]`.
5. Rendre la ligne, son liseré et les stations avec trois couches natives.
6. Tester lentement et rapidement les pincements autour de la zone de fade sur le simulateur et un iPhone réel.
7. Mesurer FPS et mémoire, puis seulement remplacer définitivement l'écran `expo-maps`.

Critère d'acceptation : aucun changement de rayon ou d'opacité ne doit survenir après le relâchement du pincement ; à vue globale, les stations sont invisibles ; en vue locale, elles apparaissent progressivement, restent petites et parfaitement centrées sur le tracé.
