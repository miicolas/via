# PRIM — jeu de données « Positionnement dans la rame »

Date de vérification : 23 août 2026.

## Objet et méthode

Cette note évalue le jeu officiel PRIM « Positionnement dans la rame » pour une réutilisation dans Via. Elle s’appuie uniquement sur des sources primaires : la [fiche PRIM](https://prim.iledefrance-mobilites.fr/fr/jeux-de-donnees/positionnement-dans-la-rame), le [catalogue Open Data d’Île-de-France Mobilités](https://data.iledefrance-mobilites.fr/explore/dataset/positionnement-dans-la-rame/), ses [métadonnées API](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame) et l’[export JSON complet](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/exports/json).

Les cardinalités ci-dessous ont été recalculées sur les 5 239 lignes de l’export complet, sans échantillonnage. Les « stations » désignent des libellés `from_name`, pas des gares canoniques : le jeu ne fournit pas d’identifiant de gare.

## Verdict pour Via

Le nom du jeu peut prêter à confusion : il ne localise ni une rame ni un voyageur en temps réel. Chaque ligne indique, depuis un point d’arrêt RATP précis, la zone et la voiture conseillées pour atteindre une sortie ou une correspondance. C’est donc une bonne donnée statique d’enrichissement d’itinéraire, pas une source de position des trains. La RATP indique que ces données sont déjà utilisées dans l’application et le site Île-de-France Mobilités. ([Fiche et description officielles](https://data.iledefrance-mobilites.fr/explore/dataset/positionnement-dans-la-rame/information/))

La couverture est beaucoup plus large que quelques stations : l’export contient 5 239 recommandations sur les 16 lignes de métro RATP — 1 à 14, 3 bis et 7 bis — et les RER A et B. En revanche, il ne couvre aucun autre RER, Transilien, tramway ou bus. Son utilité dépend d’une condition stricte : Via doit connaître le `from_id` exact du point d’arrêt où le voyageur descend et le `to_id` exact de la sortie ou du point de correspondance visé. Une jointure par nom de station ou par ligne seule donnerait des conseils inversés ou ambigus.

Le conseil doit rester facultatif. La source ne publie aucune fréquence de mise à jour, ses données n’ont pas changé depuis le 18 février 2025, elle omet officiellement Châtelet sur les RER A et B et elle ne décrit ni la direction en clair ni la composition réelle de la rame du voyage. ([Métadonnées officielles](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame))

## Contenu et schéma

Une recommandation relie un point de départ `from_*` à une cible `to_*`, sur une ligne commerciale donnée, puis indique la position à choisir. Les douze champs sont tous présents sur les 5 239 lignes, sauf `equipment_type`, qui est vide sur 4 285 lignes. Le schéma et les descriptions viennent des [métadonnées officielles](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame).

| Champ | Type API | Description officielle | Valeurs observées ou précision |
| --- | --- | --- | --- |
| `from_type` | texte | Type du point de départ | Toujours `stop_point` |
| `from_id` | entier | Identifiant Référentiel du point de départ | Identifie le point d’arrêt précis ; 952 valeurs distinctes dans l’export |
| `from_name` | texte | Nom du point de départ | 376 libellés distincts ; ce n’est pas une clé |
| `line_id` | texte | Identifiant de référence de ligne commerciale | 18 valeurs, par exemple `C01371` pour la ligne 1 |
| `line_name` | texte | Nom commercial de la ligne | `1` à `14`, `3B`, `7B`, `A`, `B` |
| `to_type` | texte | Type du point d’arrivée | `access_point` sur 3 834 lignes ; `stop_point` sur 1 405 lignes |
| `to_id` | entier | Identifiant Référentiel du point d’arrivée | 1 476 valeurs distinctes |
| `to_name` | texte | Nom du point d’arrivée | Adresse ou nom de la sortie, ou nom du point de correspondance |
| `position_average` | texte | Zone dans laquelle se positionner | `Avant` 2 332 fois, `Milieu` 824 fois, `Arrière` 2 082 fois, plus une valeur anormale `7` |
| `position` | entier | Voiture dans laquelle se positionner | Toutes les valeurs observées sont comprises entre 1 et `position_max` |
| `position_max` | entier | Nombre de voitures sur la ligne | Valeurs observées : 3, 5, 6, 8 ou 10 |
| `equipment_type` | texte | Équipement disponible entre le point de départ et le point d’arrivée | `Escalator` 478 fois, `Ascenseur` 341 fois, `Escalier` 135 fois, `null` 4 285 fois |

L’[API d’enregistrements](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/records?limit=2) renvoie une enveloppe `{ total_count, results }` et des objets plats. Par exemple, une ligne relie un `stop_point` de la ligne 7 à Châtelet à un autre `stop_point`, avec `position = 5`, `position_max = 5` et `position_average = Arrière`.

### Une cible peut avoir plusieurs positions

Le jeu n’a pas d’identifiant de recommandation et le couple départ/cible n’est pas unique. Sur 4 287 clés distinctes `(from_id, line_id, to_type, to_id)`, 574 possèdent plusieurs lignes, jusqu’à 11. Dans 536 de ces 574 cas, plusieurs voitures différentes sont proposées ; dans 385 cas, plusieurs valeurs d’équipement sont présentes. L’[exemple officiel filtré de République](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/records?where=from_id%3D21902%20and%20to_id%3D50148407&order_by=position&limit=100) recommande ainsi les voitures 2 et 3 pour la même sortie.

Il ne faut donc pas imposer une unicité sur `(from_id, to_id)` ni écraser une ligne par la suivante. Le modèle de Via doit conserver une liste d’options. Le jeu ne fournit aucun identifiant de chemin ou ordre de préférence qui permettrait de choisir automatiquement entre elles.

## Accès, téléchargements et API

Tous les accès ci-dessous répondaient publiquement, sans jeton, à la date de vérification. Cela décrit le comportement observé du catalogue Open Data, pas une garantie de niveau de service.

| Usage | Format | URL officielle | Remarque |
| --- | --- | --- | --- |
| Fiche et exploration | HTML | [Catalogue IDFM](https://data.iledefrance-mobilites.fr/explore/dataset/positionnement-dans-la-rame/) | Tableau, filtres, informations et téléchargements |
| Métadonnées et schéma | JSON | [Jeu v2.1](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame) | Compteur, dates, licence et définition des champs |
| Lecture filtrée et paginée | JSON | [Records, 100 lignes](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/records?limit=100) | `limit` est borné à 100 ; utiliser `offset`, `where`, `select`, `group_by` ou les exports |
| Export complet | CSV | [Télécharger le CSV](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/exports/csv?lang=fr&timezone=Europe%2FParis&use_labels=false&delimiter=%3B) | Séparateur `;` dans cette URL |
| Export complet | JSON | [Télécharger le JSON](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/exports/json) | Tableau JSON directement importable |
| Export complet | XLSX | [Télécharger le classeur](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/exports/xlsx) | Pour inspection manuelle |
| Export complet | Parquet | [Télécharger le Parquet](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/exports/parquet) | Adapté à un traitement analytique |
| Export complet | GeoJSON | [Télécharger le GeoJSON](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/exports/geojson) | Chaque `geometry` est `null` : le jeu n’a aucune coordonnée |
| Export complet | Turtle/RDF | [Télécharger le Turtle](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/exports/turtle) | Exposé par l’API, inutile pour le client iOS |

Pour un import de référence, l’export complet est plus simple et plus cohérent que 53 pages API. Pour une inspection ciblée, l’API filtrée permet par exemple de demander [toutes les recommandations d’un point d’arrêt](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/records?where=from_id%3D463060&order_by=to_type%2Cto_id%2Cposition&limit=100).

## Couverture par ligne

Le tableau suivant est calculé sur l’[export officiel complet](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/exports/json). « Points de départ » compte les `from_id` distincts ; « libellés » compte les `from_name` distincts à l’intérieur de la ligne. Les deux dernières colonnes comptent les lignes de données, pas les cibles distinctes.

| Ligne | `line_id` | Recommandations | Points de départ | Libellés de station | Vers `access_point` | Vers `stop_point` |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | `C01371` | 354 | 50 | 25 | 238 | 116 |
| 2 | `C01372` | 222 | 50 | 25 | 127 | 95 |
| 3 | `C01373` | 227 | 50 | 25 | 155 | 72 |
| 3 bis | `C01386` | 23 | 8 | 4 | 15 | 8 |
| 4 | `C01374` | 428 | 62 | 30 | 272 | 156 |
| 5 | `C01375` | 257 | 44 | 22 | 154 | 103 |
| 6 | `C01376` | 220 | 55 | 28 | 149 | 71 |
| 7 | `C01377` | 370 | 76 | 38 | 292 | 78 |
| 7 bis | `C01387` | 41 | 13 | 8 | 25 | 16 |
| 8 | `C01378` | 400 | 76 | 38 | 305 | 95 |
| 9 | `C01379` | 407 | 74 | 37 | 302 | 105 |
| 10 | `C01380` | 145 | 39 | 23 | 101 | 44 |
| 11 | `C01381` | 314 | 38 | 19 | 258 | 56 |
| 12 | `C01382` | 278 | 62 | 31 | 215 | 63 |
| 13 | `C01383` | 364 | 65 | 32 | 288 | 76 |
| 14 | `C01384` | 689 | 39 | 20 | 557 | 132 |
| RER A | `C01742` | 298 | 85 | 34 | 227 | 71 |
| RER B | `C01743` | 202 | 66 | 28 | 154 | 48 |
| **Total** | 18 lignes | **5 239** | **952** | **467 couples ligne/libellé** | **3 834** | **1 405** |

Les 467 couples `(line_id, from_name)` ne sont pas 467 gares physiques : une même gare apparaît sur plusieurs lignes. L’export contient 376 chaînes `from_name` distinctes au total.

### Points d’arrêt, quais et directions

La source appelle chaque départ un `stop_point`, pas un quai, et ne contient aucun champ `direction`, `destination`, `terminus`, numéro de quai, voie ou branche. La direction est seulement implicite dans `from_id`. À [Gare de Lyon sur la ligne 1](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/records?where=from_name%3D%27Gare%20de%20Lyon%27%20and%20line_name%3D%271%27&order_by=from_id%2Cto_id%2Cposition&limit=100), les deux `from_id` donnent par exemple des positions opposées vers les mêmes sorties.

La plupart des couples ligne/libellé ont deux points de départ, mais ce n’est pas une règle de direction exploitable :

- 436 sur 467 ont deux `from_id` ;
- 12 n’en ont qu’un, notamment sur les boucles des lignes 7 bis et 10 ;
- 19 en ont trois ou quatre, notamment sur les embranchements et gares à plusieurs voies des RER A et B.

Il est donc impossible de mesurer une couverture fiable « dans les deux sens » à partir de ce jeu seul. Via doit faire correspondre l’identifiant exact de point d’arrêt fourni par le référentiel ou le calculateur d’itinéraire IDFM. Quand le calculateur ne renvoie qu’une gare agrégée, le conseil doit rester absent, sauf si toutes les directions documentées publient exactement la même voiture pour la même cible.

### Cas vérifié : Chatou–Croissy

Le jeu positionnement publie les points `473964` et `473965` à Chatou–Croissy. Le [référentiel officiel Arrêts](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/arrets/records?where=arrid%3D%22473964%22%20or%20arrid%3D%22473965%22&limit=20) les rattache tous les deux à la zone d’arrêt `53783`, que Navitia expose actuellement sous la forme `stop_point:IDFM:monomodalStopPlace:53783` pour le RER A. Vers la sortie `50148532` rue Paul-Flament, les deux points recommandent la même voiture 4 sur 10, à l’avant : ce conseil peut donc être agrégé sans perdre le sens. La sortie `50148533` place Maurice-Berteaux n’est documentée que depuis un des deux points ; elle doit rester sans conseil lorsque le calculateur ne fournit que la zone agrégée.

## Licence et attribution

Les métadonnées placent le jeu sous [Licence Ouverte v2.0 Etalab](https://www.data.gouv.fr/pages/legal/licences/etalab-2.0), avec la RATP comme producteur. La licence autorise gratuitement la copie, l’adaptation, la redistribution et l’exploitation commerciale. Elle impose de mentionner la source — au minimum le concédant — et la date de dernière mise à jour de l’information réutilisée.

Une attribution adaptée dans Via ou sa documentation serait : « Source : RATP / Île-de-France Mobilités, Positionnement dans la rame — données mises à jour le 18 février 2025 ». La licence précise aussi que les données sont fournies sans garantie d’absence d’erreur ni de continuité et que la réutilisation ne doit pas induire en erreur sur le contenu, la source ou la date.

## Fréquence et fraîcheur

Aucune fréquence de mise à jour n’est publiée : `metas.default.update_frequency` et `metas.dcat.accrualperiodicity` valent `null`. Les [métadonnées API](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame) distinguent :

- dernier traitement des **données** : `2025-02-18T13:59:52+00:00` ;
- dernier traitement des **métadonnées** : `2026-07-16T13:46:11.887000+00:00`.

Le traitement récent des métadonnées ne signifie donc pas que les recommandations ont été actualisées. En l’absence de cadence contractuelle, Via doit enregistrer cette date avec le snapshot, surveiller périodiquement `data_processed` ou le contenu de l’export, et ne jamais présenter ces conseils comme temps réel.

## Limites et anomalies

### Limites publiées

- La fiche officielle indique explicitement que les positions des RER A et B à Châtelet sont manquantes. L’export ne contient effectivement aucune ligne A ou B dont `from_name` est Châtelet. ([Description officielle](https://data.iledefrance-mobilites.fr/explore/dataset/positionnement-dans-la-rame/information/))
- La fiche ne promet ni exhaustivité par ligne ou station, ni fréquence, ni continuité de service.

### Limites structurelles

- Aucun sens, terminus, numéro de quai, horaire, mission, type de rame, identifiant de véhicule, géométrie ou horodatage par recommandation.
- `position_max` décrit le nombre de voitures « sur la ligne », pas la composition du train réellement attendu. Le jeu ne permet pas d’adapter le conseil à une rame courte, à une composition modifiée ou à une mission particulière.
- `to_id` et `from_id` sont annoncés comme identifiants Référentiel, mais la fiche ne documente ni le jeu précis auquel les joindre, ni leur stabilité. Les noms ne constituent pas une solution de repli sûre.
- Le jeu ne donne pas les coordonnées des sorties. Choisir la meilleure sortie pour la destination exige de joindre `to_id` à un référentiel officiel tel que le jeu [Accès](https://data.iledefrance-mobilites.fr/explore/dataset/acces/).
- `equipment_type` est absent sur 81,8 % des lignes et ne porte aucun état de fonctionnement. La présence d’`Ascenseur` ne garantit pas que l’ascenseur soit opérationnel au moment du trajet.
- Les multiples recommandations pour une même cible n’ont ni identifiant de chemin ni priorité ; il faut les conserver sans inventer un classement.

### Anomalies mesurées dans l’export

- Une ligne Gare de Lyon, RER A contient `position_average = "7"` au lieu de `Avant`, `Milieu` ou `Arrière`, avec `position = 7` sur 10. ([Enregistrement officiel](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/records?where=from_id%3D474062%20and%20to_id%3D50148653&limit=100))
- Les libellés de la ligne 14 comprennent encore `Chevilly-Larue? (Marché International?)`, `Thiais - Orly? (Pont de Rungis?)` et un caractère mal encodé dans `Aéroport dOrly (Terminaux 1-2-3)`. ([Ligne 14 filtrée](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/records?where=line_name%3D%2714%27&select=from_name&group_by=from_name&order_by=from_name&limit=100))
- L’export ne contient pas `Villejuif – Gustave Roussy`.
- L’agrégation serveur `count(distinct from_id)` renvoie 927 et `count(distinct from_name)` 369, alors que le décompte exact de l’export complet renvoie respectivement 952 et 376. ([Agrégat officiel](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/records?select=count%28distinct%20from_id%29%20as%20from_ids%2Ccount%28distinct%20from_name%29%20as%20from_names%2Ccount%28%2A%29%20as%20rows&limit=1)) Les audits de couverture doivent donc compter l’export exhaustif plutôt que dépendre de cet agrégat.

## Intégration recommandée dans une app iOS de transport

1. **Importer côté serveur.** Télécharger périodiquement l’export JSON ou Parquet, conserver `data_processed`, attribuer la source et servir au client seulement le conseil utile à son itinéraire. L’iPhone n’a pas besoin de télécharger le référentiel complet à chaque recherche.
2. **Résoudre des identifiants, pas des noms.** Pour une section de transport, utiliser le point d’arrêt exact où le voyageur descend comme `from_id`, puis la sortie ou le prochain point d’arrêt comme `(to_type, to_id)`. Inclure `line_id` dans la jointure et refuser toute correspondance approximative par libellé. Le référentiel `arrets` permet de relier `from_id` à `zdaid`, mais une recommandation au niveau `zdaid` n’est sûre que si l’intersection des choix de tous ses points d’arrêt contient une seule voiture.
3. **Conserver toutes les options.** Modéliser plusieurs `(position, position_average, equipment_type)` par cible. Une préférence d’accessibilité peut favoriser une option avec ascenseur, mais l’absence ou la présence d’un équipement ne doit pas devenir une promesse d’accessibilité opérationnelle.
4. **Afficher la zone avant la voiture.** Le message principal devrait rester « à l’avant », « au milieu » ou « à l’arrière » ; « voiture 5 sur 5 » est un détail indicatif. Pour la valeur anormale `7`, recalculer prudemment la zone depuis `position / position_max` ou omettre la zone source.
5. **Dégrader silencieusement.** Si le trajet ne fournit pas les identifiants de point d’arrêt, si aucune ligne ne correspond, si la longueur de rame n’est pas confirmée ou si la donnée paraît incohérente, afficher l’itinéraire sans conseil de placement.
6. **Ne pas confondre avec le temps réel.** Qualifier la donnée comme conseil de placement statique, sans indicateur « live ». Sa valeur produit est maximale dans le détail d’une section, la préparation d’une correspondance et le guidage actif juste avant l’embarquement.

Ce jeu peut donc augmenter fortement la couverture de Via sur le métro RATP et les portions documentées des RER A/B, à condition de rester un enrichissement optionnel, directionnel par `stop_point`, versionné et explicitement tolérant aux absences.

## Sources primaires

- [PRIM — Positionnement dans la rame](https://prim.iledefrance-mobilites.fr/fr/jeux-de-donnees/positionnement-dans-la-rame)
- [Open Data Île-de-France Mobilités — fiche du jeu](https://data.iledefrance-mobilites.fr/explore/dataset/positionnement-dans-la-rame/information/)
- [Open Data Île-de-France Mobilités — métadonnées et schéma API v2.1](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame)
- [Open Data Île-de-France Mobilités — export JSON complet](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/positionnement-dans-la-rame/exports/json)
- [data.gouv.fr — Licence Ouverte 2.0](https://www.data.gouv.fr/pages/legal/licences/etalab-2.0)
