# Navigation mobile

Expo Router ne contient que des routes et leurs layouts. Les composants, hooks
et utilitaires restent dans les dossiers voisins de `src/app`.

## Arborescence

```text
src/app/
├── _layout.tsx
├── (onboarding)/
│   ├── _layout.tsx
│   └── welcome/
│       ├── _layout.tsx
│       └── index.tsx
├── (auth)/
│   ├── _layout.tsx
│   ├── sign-in/
│   │   ├── _layout.tsx
│   │   └── index.tsx
│   └── sign-up/
│       ├── _layout.tsx
│       └── index.tsx
└── (app)/
    ├── _layout.tsx
    └── (tabs)/
        ├── _layout.tsx
        ├── (home)/
        │   ├── _layout.tsx
        │   └── index.tsx
        ├── map/
        │   ├── _layout.tsx
        │   └── index.tsx
        └── explore/
            ├── _layout.tsx
            └── index.tsx
```

Les groupes entre parenthèses structurent la navigation sans modifier l’URL.
Ainsi `(home)/index.tsx` répond à `/`, tandis que `map/index.tsx` répond à
`/map`.

## Ajouter une page

Chaque page possède son propre dossier, un `_layout.tsx` et un `index.tsx` :

```text
(app)/profile/
├── _layout.tsx
└── index.tsx
```

Les sous-pages éventuelles sont ajoutées dans ce même dossier. Le fichier
`index.tsx` reste l’entrée de la page et délègue les composants complexes à
`src/components`.

## Ajouter une sheet

Une sheet suit exactement la même convention qu’une page. Sa présentation est
déclarée dans le layout parent :

```text
(app)/(sheets)/station-details/
├── _layout.tsx
└── index.tsx
```

Le groupe `(sheets)` sera créé avec la première sheet réelle afin de ne pas
ajouter de route vide. Son layout utilisera `presentation: 'formSheet'`.

## Authentification

Les groupes sont prêts à recevoir les guards Expo Router. Ils seront branchés
dans le layout racine une fois l’état de session et la persistance choisis :

- onboarding visible tant qu’il n’est pas terminé ;
- auth visible sans session ;
- app visible avec une session valide.
