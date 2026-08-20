# Captures et illustrations App Store iPhone — exigences Apple

Date de vérification : 20 août 2026.

## Objet et méthode

Cette note rassemble les exigences et recommandations utiles pour produire dans Paper les visuels App Store iPhone de Via. Elle s’appuie exclusivement sur les pages actuelles d’Apple Developer, App Store Connect Help et App Review Guidelines.

## Décision exécutable pour Paper

- Créer les artboards finaux en **portrait 1320 × 2868 px** : c’est la plus grande des trois dimensions acceptées par Apple pour la famille iPhone 6,9 pouces. Exporter en PNG, JPG ou JPEG, sans transparence ni canal alpha. ([Apple — Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/))
- Un jeu 6,9 pouces suffit pour une app dont l’interface reste identique entre tailles : App Store Connect réduit automatiquement les visuels pour les écrans plus petits. Le jeu 6,5 pouces n’est obligatoire que si aucun jeu 6,9 pouces n’est fourni. ([Apple — Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/), [Apple — Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/))
- Traiter chaque visuel comme une **capture de l’app enrichie**, pas comme une affiche autonome : l’app en usage doit rester clairement visible ; Apple autorise les overlays texte et image, mais déconseille de consacrer tout le visuel à des récompenses génériques ou à un appel à l’action. ([Apple — App Review Guidelines, 2.3.3](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata), [Apple — App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/))
- Concevoir d’abord les trois premiers visuels autour des fonctions ou bénéfices les plus forts, puis ordonner les suivants comme une histoire cohérente de l’usage. Sans app preview, les un à trois premiers screenshots peuvent apparaître dans les résultats de recherche selon leur orientation. ([Apple — Creating Your Product Page](https://developer.apple.com/app-store/product-page/), [Apple — App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/))
- Décliner séparément le texte et les captures pour chaque langue prise en charge ; Apple recommande de localiser screenshots et app previews pour chaque marché où l’app est proposée. ([Apple — Creating Your Product Page](https://developer.apple.com/app-store/product-page/), [Apple — App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/))

## Dimensions iPhone acceptées

Apple accepte de **un à dix screenshots** par jeu, en `.png`, `.jpg` ou `.jpeg`, sans canal alpha ni transparence. ([Apple — Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/))

| Famille d’affichage | Portrait accepté | Paysage accepté | Comportement si le jeu manque |
| --- | --- | --- | --- |
| 6,9 pouces | 1260 × 2736 ; 1290 × 2796 ; 1320 × 2868 px | 2736 × 1260 ; 2796 × 1290 ; 2868 × 1320 px | Jeu de tête actuel. ([Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)) |
| 6,5 pouces | 1284 × 2778 ; 1242 × 2688 px | 2778 × 1284 ; 2688 × 1242 px | Obligatoire seulement sans jeu 6,9 pouces ; sinon Apple utilise la version 6,9 pouces réduite. ([Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)) |
| 6,3 pouces | 1179 × 2556 ; 1206 × 2622 px | 2556 × 1179 ; 2622 × 1206 px | Apple utilise la version 6,5 pouces réduite. ([Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)) |
| 6,1 pouces | 1170 × 2532 ; 1125 × 2436 ; 1080 × 2340 px | 2532 × 1170 ; 2436 × 1125 ; 2340 × 1080 px | Apple utilise la version 6,5 pouces réduite. ([Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)) |
| 5,5 pouces | 1242 × 2208 px | 2208 × 1242 px | Apple utilise la version 6,1 pouces réduite. ([Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)) |
| 4,7 pouces | 750 × 1334 px | 1334 × 750 px | Apple utilise la version 5,5 pouces réduite. ([Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)) |
| 4 pouces | 640 × 1096 sans barre d’état ; 640 × 1136 avec barre d’état | 1136 × 600 sans barre d’état ; 1136 × 640 avec barre d’état | Apple utilise la version 4,7 pouces réduite. ([Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)) |
| 3,5 pouces | 640 × 920 sans barre d’état ; 640 × 960 avec barre d’état | 960 × 600 sans barre d’état ; 960 × 640 avec barre d’état | Apple utilise la version 4 pouces réduite. ([Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)) |

Le choix recommandé pour le master Paper est donc **1320 × 2868 px portrait**. Il correspond à une dimension 6,9 pouces acceptée et évite de maintenir tous les jeux lorsqu’aucune adaptation réelle de l’interface ne les justifie. Cette recommandation déduit le flux le plus simple de la règle Apple de soumission à la plus haute résolution puis de réduction automatique. ([Apple — Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/))

## Contenu admissible et limites marketing

- Les screenshots et previews doivent représenter fidèlement l’expérience principale, rester à jour avec les nouvelles versions et ne pas promettre une fonction ou un contenu absent de l’app. ([Apple — App Review Guidelines, 2.3](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata))
- Un screenshot doit montrer l’app en usage ; un écran titre, une page de connexion ou un splash screen seuls ne suffisent pas. Les overlays texte ou image sont explicitement admis. ([Apple — App Review Guidelines, 2.3.3](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata))
- Si un visuel présente un élément, une fonction ou un abonnement nécessitant un achat intégré, il doit l’indiquer clairement. ([Apple — App Review Guidelines, 2.3.2](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata))
- Les visuels ne doivent pas inclure de prix précis, remise, URL de site ou symbole de copyright ; ils ne doivent pas contenir de revendication invérifiable ni de reconnaissance Apple telle que « App of the Day » ou « Apple Design Award winner ». ([Apple — App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/))
- Les noms, icônes ou images d’autres plateformes mobiles et marketplaces sont à exclure, sauf fonctionnalité interactive spécifique approuvée ; les métadonnées doivent rester centrées sur l’app et son expérience. ([Apple — App Review Guidelines, 2.3.10](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata))
- Tous les visuels App Store doivent convenir à une classification **4+**, même si l’app possède une classification plus élevée. ([Apple — App Review Guidelines, 2.3.8](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata), [Apple — App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/))
- Le développeur doit disposer des droits sur chaque élément affiché et remplacer les informations de comptes réels par des données fictives. ([Apple — App Review Guidelines, 2.3.9](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata))

### Place exacte de l’illustration

Dans un screenshot, l’illustration, la couleur de fond, les repères graphiques et le texte peuvent soutenir l’interface, mais ne doivent pas la remplacer : Apple présente screenshots et app previews comme les médias de l’app **en usage**, et distingue les « creative assets », conçus notamment pour mettre en avant la marque, des offres saisonnières ou de nouveaux contenus. ([Apple — App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/))

Ces creative assets séparés apparaissent sur la fiche produit, dans la recherche et dans les sélections à partir d’iOS 27 et iPadOS 27 ; ils ne remplacent donc pas le besoin de produire aujourd’hui un jeu de screenshots conforme pour Via sur iOS 26. ([Apple — App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/))

## Composition, texte et cohérence de la série

- Utiliser l’interface la plus récente et fidèle à l’esthétique de l’app ; donner à chaque image une composition forte et un point focal clair. ([Apple — App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/))
- Employer une phrase courte qui **renforce** le visuel plutôt qu’une phrase qui le décrit, garder tout texte lisible et localiser ce texte dans toutes les langues prises en charge. ([Apple — App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/))
- Garder les éléments essentiels et le point focal vers le centre afin d’absorber les recadrages possibles selon l’emplacement, l’appareil ou l’orientation ; contrôler le rendu avec l’outil Preview d’App Store Connect. ([Apple — App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/))
- Faire fonctionner les screenshots comme une série : même palette, typographie, iconographie, ton et style d’illustration, tout en donnant à chaque visuel une fonction ou un bénéfice distinct. ([Apple — App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/), [Apple — Creating Your Product Page](https://developer.apple.com/app-store/product-page/))
- Commencer par les fonctions les plus convaincantes et les séquencer dans un ordre qui reflète l’usage réel ; éviter qu’un artboard entier ne soit qu’une récompense, un slogan générique ou un appel à l’action. ([Apple — App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/))
- Si Via prend en charge le mode sombre, Apple conseille d’en montrer au moins un exemple dans la série. ([Apple — Creating Your Product Page](https://developer.apple.com/app-store/product-page/))

### Storyboard Paper recommandé

Cette structure est une traduction directe des priorités Apple, à remplir avec les fonctionnalités réelles de Via :

1. `01 · Promesse principale` — bénéfice central, interface principale immédiatement reconnaissable.
2. `02 · Fonction forte` — première action ou résultat différenciant.
3. `03 · Fonction forte` — second bénéfice décisif ; ces trois premiers artboards forment aussi le résumé potentiel en recherche.
4. `04–10 · Histoire d’usage` — une fonction ou un bénéfice par image, dans l’ordre d’un parcours réel ; n’utiliser les dix emplacements que s’ils ajoutent chacun une information utile.

Cette hiérarchie est une recommandation de production fondée sur l’affichage possible des trois premiers screenshots en recherche et sur la consigne Apple de mener avec les meilleures fonctions puis de raconter une histoire cohérente. ([Apple — Creating Your Product Page](https://developer.apple.com/app-store/product-page/), [Apple — App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/))

## Ordre réel dans l’App Store

- Une app preview vidéo précède toujours les screenshots sur iPhone, iPad, Mac et Apple TV, même si l’ordre paraît différent lors de l’édition dans App Store Connect. ([Apple — Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/))
- Sans app preview, les un à trois premiers screenshots peuvent être repris dans les résultats de recherche selon leur orientation ; ils doivent donc résumer l’essence de l’app sans dépendre des visuels suivants. ([Apple — Creating Your Product Page](https://developer.apple.com/app-store/product-page/))
- À partir d’iOS 27, un asset créatif spécifique peut occuper le résultat de recherche ; sans cet asset, les In-App Events, app previews et screenshots continuent d’être utilisés. ([Apple — App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/))

## Localisation

- Apple recommande de localiser la description, les mots-clés, les app previews et les screenshots pour chaque marché dans lequel l’app est proposée. ([Apple — Creating Your Product Page](https://developer.apple.com/app-store/product-page/))
- Lorsqu’une langue est ajoutée dans App Store Connect, ses screenshots et la plupart de ses propriétés reprennent d’abord ceux de la langue principale ; ils restent donc non localisés tant qu’un jeu spécifique n’est pas fourni. ([Apple — Localize app information](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information))
- Si une app preview localisée manque, App Store Connect affiche la preview de la prochaine langue jugée pertinente ; pour contrôler exactement la langue de la vidéo dans chaque storefront, Apple demande d’en fournir une pour chaque locale prise en charge. ([Apple — Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/))
- Pour changer la langue principale, les screenshots de la nouvelle langue doivent avoir été approuvés pour toutes les plateformes et leurs tailles doivent correspondre à celles de la langue principale actuelle. ([Apple — Localize app information](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information))

Conséquence pour Paper : conserver un master visuel commun et séparer les textes en composants ou variantes par locale permet de préserver la cohérence de la série tout en respectant la recommandation Apple de traduire chaque image. Cette organisation est une inférence de production, pas une contrainte technique imposée par App Store Connect. ([Apple — App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/))

## App previews iPhone

- L’app preview est facultative ; il est possible d’en fournir jusqu’à trois par taille d’appareil et par langue prise en charge. Elle dure de **15 à 30 secondes**, pèse au maximum **500 Mo** et accepte H.264 ou ProRes 422 HQ, à 30 i/s maximum. ([Apple — App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/), [Apple — Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/))
- Pour les iPhone modernes 6,9, 6,5, 6,3 et 6,1 pouces, la résolution de preview acceptée est **886 × 1920 px** en portrait ou **1920 × 886 px** en paysage. ([Apple — App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/))
- Une preview iOS ne peut utiliser que de la capture vidéo de l’app elle-même ; il ne faut pas filmer une personne, un appareil ou des doigts. Narration, texte et overlays vidéo sont autorisés pour clarifier ce que la capture ne montre pas seule. ([Apple — App Review Guidelines, 2.3.4](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata), [Apple — Show more with app previews](https://developer.apple.com/app-store/app-previews/))
- Les previews démarrent automatiquement avec le son coupé : les premières secondes doivent être visuellement fortes et la vidéo doit rester compréhensible sans audio. Un poster frame convaincant doit représenter clairement l’app lorsque l’autoplay est désactivé. ([Apple — Creating Your Product Page](https://developer.apple.com/app-store/product-page/), [Apple — Show more with app previews](https://developer.apple.com/app-store/app-previews/))
- Plusieurs previews doivent former une histoire cohérente et montrer chacune quelque chose de nouveau ; toute fonction soumise à achat, abonnement ou connexion doit être signalée dans la vidéo ou son écran final. ([Apple — Show more with app previews](https://developer.apple.com/app-store/app-previews/))
- Le contenu doit rester dans l’app, convenir à tous les âges et n’utiliser que des éléments dont les droits marketing sont acquis dans tous les territoires concernés. ([Apple — Show more with app previews](https://developer.apple.com/app-store/app-previews/))

Pour Via, la production statique dans Paper doit donc venir en premier. Une app preview ne vaut la peine que si un mouvement ou un enchaînement réel communique mieux la valeur que les captures ; puisqu’elle passera avant toutes les images, elle doit être au moins aussi claire que le premier artboard. Cette priorité est une recommandation déduite de l’ordre d’affichage imposé par Apple. ([Apple — Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/))

## Contrôle qualité avant export

- [ ] Chaque fichier final mesure exactement 1320 × 2868 px, est en PNG/JPG/JPEG et ne contient ni alpha ni transparence. ([Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/))
- [ ] L’interface réelle et actuelle de Via reste le sujet principal de chaque image. ([Apple](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata))
- [ ] Les trois premiers visuels suffisent à comprendre l’essence et les bénéfices centraux de l’app. ([Apple](https://developer.apple.com/app-store/product-page/))
- [ ] Chaque artboard suivant ajoute un bénéfice ou une fonction et conserve palette, typographie, iconographie et ton communs. ([Apple](https://developer.apple.com/app-store/asset-best-practices/))
- [ ] Les overlays sont courts, lisibles, exacts et localisés ; aucun prix, remise, URL, prix Apple ou affirmation invérifiable n’apparaît. ([Apple](https://developer.apple.com/app-store/asset-best-practices/))
- [ ] Les contenus conviennent à une classification 4+ et les comptes visibles utilisent des données fictives. ([Apple](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata))
- [ ] Les droits de toute photo, carte, marque, musique ou autre propriété intellectuelle visible sont acquis pour les territoires visés. ([Apple](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata))
- [ ] Le rendu est contrôlé dans le Preview d’App Store Connect pour détecter recadrage et manque de lisibilité. ([Apple](https://developer.apple.com/app-store/asset-best-practices/))
- [ ] Les variantes importantes peuvent ensuite être comparées par Product Page Optimization ; Apple permet de tester jusqu’à trois traitements alternatifs de l’icône, des screenshots et des app previews. ([Apple — Product Page Optimization](https://developer.apple.com/app-store/product-page-optimization/))

## Sources primaires Apple

- [Screenshot specifications — App Store Connect Help](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Upload app previews and screenshots — App Store Connect Help](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)
- [App preview specifications — App Store Connect Help](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/)
- [Localize app information — App Store Connect Help](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information)
- [App Review Guidelines — Accurate Metadata](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)
- [Creating Your Product Page — Apple Developer](https://developer.apple.com/app-store/product-page/)
- [App Store asset best practices and resources — Apple Developer](https://developer.apple.com/app-store/asset-best-practices/)
- [Show more with app previews — Apple Developer](https://developer.apple.com/app-store/app-previews/)
- [Product Page Optimization — Apple Developer](https://developer.apple.com/app-store/product-page-optimization/)
