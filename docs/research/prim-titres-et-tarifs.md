# PRIM — « Titres et tarifs » et tarification des itinéraires Via

Date de vérification : 29 août 2026.

## Objet et méthode

Cette note évalue le jeu officiel PRIM [« Description et tarif des titres de transport en Île-de-France »](https://prim.iledefrance-mobilites.fr/fr/jeux-de-donnees/titres-et-tarifs) pour afficher un tarif à côté de l'estimation de CO₂e d'un trajet Via. Elle distingue deux sources officielles qui n'ont pas le même rôle :

- le jeu Open Data `titres-et-tarifs`, catalogue éditorial public de produits ;
- le champ `fare` de la réponse de l'[API Calculateur Île-de-France Mobilités — accès générique](https://prim.iledefrance-mobilites.fr/fr/apis/idfm-navitia-general-v2), qui chiffre un itinéraire précis.

Les constats sur le catalogue ont été recalculés sur les 29 lignes de l'[export JSON officiel complet](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/titres-et-tarifs/exports/json). Ceux sur le calculateur ont été vérifiés contre des réponses live de l'endpoint PRIM utilisé par Via, avec un jeton, sans conserver ni publier ce jeton. La documentation technique Navitia est une source primaire explicitement reliée par la [fiche API IDFM](https://prim.iledefrance-mobilites.fr/fr/apis/idfm-navitia-general-v2#documentation-technique).

## Verdict pour Via

Le jeu `titres-et-tarifs` ne permet **pas** de calculer le prix d'un trajet. Il contient 29 fiches de produits, avec un prix d'appel textuel, une description, des liens et des images, mais aucune règle structurée de mode, zone, origine/destination, correspondance, éligibilité ou validité commerciale. Le joindre à un trajet par nom de produit ou par mode produirait notamment des erreurs sur les trajets mixtes, les aéroports, les forfaits, les réductions et les anciens titres encore présents dans le catalogue.

La bonne source nominale existe déjà dans la réponse de calcul d'itinéraire PRIM/Navitia : chaque objet `journey` peut porter `fare.found`, `fare.total` et des liens vers les `tickets` de la réponse. La [documentation officielle Navitia](https://doc.navitia.io/#journeys) définit précisément `fare` comme le tarif du trajet, avec les tickets et le prix. Les essais live ont confirmé que le calculateur distingue correctement un Ticket Bus-Tram à 2,05 €, un Ticket Métro-Train-RER à 2,55 €, leur somme à 4,60 € pour un trajet mixte, et le titre aéroport à 14 €.

Via devrait donc :

1. reprendre le total `fare` de l'itinéraire PRIM déjà téléchargé, sans appel réseau supplémentaire ;
2. l'afficher comme **« Tarif plein indicatif »**, jamais comme dépense personnelle certaine ;
3. omettre le tarif lorsque `fare.found` n'est pas `true`, que la monnaie ou la valeur est inconnue, ou que l'itinéraire vient du repli GTFS local ;
4. ne pas utiliser le catalogue statique comme repli de calcul ; il reste utile pour les libellés, les pages d'explication et un éventuel écran de découverte des produits.

Cette distinction est cohérente avec le commentaire existant de [`JourneyDetailSummaryView`](../../apps/via/via/Features/Journeys/Presentation/View/JourneyDetailSummaryView.swift) : une vue n'invente pas localement un tarif que le modèle d'itinéraire ne possède pas.

## Accès réellement consommables au catalogue

Tous les accès du tableau répondaient publiquement sans jeton à la date de vérification. Le [manifeste officiel des exports](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/titres-et-tarifs/exports) publie aussi JSONL, GeoJSON et plusieurs formats RDF ; les formats ci-dessous sont les plus utiles à Via.

| Usage | Format | URL officielle | Forme de la réponse |
| --- | --- | --- | --- |
| Fiche PRIM | HTML | [Jeu PRIM](https://prim.iledefrance-mobilites.fr/fr/jeux-de-donnees/titres-et-tarifs) | Description, producteur, licence et fraîcheur |
| Exploration | HTML | [Catalogue Open Data IDFM](https://data.iledefrance-mobilites.fr/explore/dataset/titres-et-tarifs/) | Informations, tableau et exports |
| Métadonnées et schéma | JSON | [API Explore v2.1](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/titres-et-tarifs) | Objet du jeu, champs, dates, licence et compteur |
| Lecture filtrable | JSON | [29 enregistrements triés](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/titres-et-tarifs/records?limit=100&order_by=product_name) | Enveloppe `{ total_count, results }` |
| Snapshot complet | JSON | [Export JSON](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/titres-et-tarifs/exports/json) | Tableau direct de 29 objets |
| Snapshot tabulaire | CSV | [Export CSV, séparateur `;`](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/titres-et-tarifs/exports/csv?lang=fr&timezone=Europe%2FParis&use_labels=false&delimiter=%3B) | CSV UTF-8 avec noms de champs techniques |
| Analyse | Parquet | [Export Parquet](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/titres-et-tarifs/exports/parquet) | Fichier Parquet complet |
| Inspection manuelle | XLSX | [Export XLSX](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/titres-et-tarifs/exports/xlsx) | Classeur complet |

Avec seulement 29 lignes, `records?limit=100` ou l'export JSON suffisent en un appel. Il n'y a aucune pièce jointe ni export alternatif spécifique au jeu dans les [métadonnées](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/titres-et-tarifs).

## Métadonnées, fraîcheur et licence

Les [métadonnées officielles](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/titres-et-tarifs) exposaient au moment de la vérification :

| Propriété | Valeur |
| --- | --- |
| Identifiant | `titres-et-tarifs` |
| UID du jeu | `da_nz6zta` |
| Producteur | Île-de-France Mobilités |
| Langue | français |
| Territoire | Île-de-France |
| Enregistrements | 29 |
| Fréquence DCAT | `Variable` |
| Dernier traitement des données | `2026-08-28T18:00:18Z`, soit le 28 août à 20 h 00 à Paris |
| Dernier traitement des métadonnées | `2026-08-28T18:00:18.940Z` |
| Licence | Licence Ouverte v2.0 Etalab |

La fréquence `Variable` n'est pas une cadence contractuelle. Surtout, `data_processed` est la date de traitement du jeu entier, pas la date d'effet d'un tarif : aucune ligne ne contient de début de validité, de fin de validité, de version ou d'horodatage. Une actualisation récente du catalogue ne prouve donc pas à elle seule qu'un montant vient d'entrer en vigueur.

La [Licence Ouverte 2.0](https://www.data.gouv.fr/pages/legal/licences/etalab-2.0) autorise gratuitement la reproduction, l'adaptation, la redistribution et l'exploitation commerciale. Elle impose de citer la source — au minimum le concédant — et la date de dernière mise à jour de l'information réutilisée, et interdit d'induire en erreur sur le contenu, la source ou la date. Une attribution adaptée à un snapshot serait :

> Source : Île-de-France Mobilités, « Description et tarif des titres de transport en Île-de-France », données traitées le 28 août 2026.

Cette licence est celle du **catalogue Open Data**. La [fiche du calculateur PRIM](https://prim.iledefrance-mobilites.fr/fr/apis/idfm-navitia-general-v2#conditions-generales-dutilisation-de-lapi-et-licence-des-donnees) place les réponses de l'API sous Licence Mobilité et ses CGU. Réutiliser le champ `fare` de la réponse déjà consommée par Via reste donc dans le cadre de licence de cette API ; la Licence Ouverte du catalogue ne se substitue pas à lui.

## Schéma du jeu `titres-et-tarifs`

Les types et descriptions viennent des [métadonnées de schéma](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/titres-et-tarifs). La complétude et les valeurs sont mesurées sur l'[export officiel du 29 août 2026](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/titres-et-tarifs/exports/json).

| Champ | Type | Description officielle ou fonction | Valeurs non vides |
| --- | --- | --- | ---: |
| `product_name` | texte | Nom complet du produit | 29/29, 29 valeurs distinctes |
| `short_description` | texte | Description du produit | 29/29 |
| `price` | texte | Tarif éditorial, sans description de schéma | 29/29, 19 valeurs distinctes |
| `price_indication` | texte | Indication sur le produit | 22/29 |
| `price_period` | texte | Période de validité du produit | 21/29 |
| `url` | texte | Lien vers la page officielle du titre | 29/29 |
| `selling_arguments` | texte | Arguments séparés par des `;`, champ non décrit | 26/29 |
| `other_product_tag` | texte | Type éditorial d'appel à l'action, champ non décrit | 11/29 |
| `duration_new_fr` | texte | Durée d'application du titre | 0/29 |
| `duration_new_en` | texte | Durée d'application en anglais | 0/29 |
| `profile_new_fr` | texte | Profil du voyageur | 0/29 |
| `profile_new_en` | texte | Profil en anglais | 0/29 |
| `definition_cta_url_button_cta_url_url` | texte | Lien du bouton de recharge ou souscription | 17/29 |
| `visual_image_mini_url` | texte | URL de l'image du produit | 29/29 |
| `visual_image_mini_alt` | texte | Description accessible de l'image | 28/29 |
| `ishighlightable` | entier | Drapeau éditorial non décrit | 29/29, toujours `0` |

Le champ `price` n'est pas de l'argent machine : ses 19 valeurs distinctes mélangent des montants (`2,05€`, `90,80€`), des prix d'appel (`dès 1,64€`, `dès 30,60€`), des réductions (`-50%`, `-75%`), `Gratuit`, `Gratuité` et `Prix variable`. Il n'y a ni montant numérique séparé, ni devise, ni identifiant de produit documenté. `product_name` et `url` sont uniques dans le snapshot, mais le schéma ne les déclare ni comme clés ni comme identifiants stables.

Les quatre champs qui pourraient porter la durée ou le profil sont vides partout. Les vraies règles vivent uniquement dans les pages web pointées par `url`, sous forme de prose et de tableaux.

## Pourquoi le catalogue ne peut pas être joint à un trajet

Aucune des 16 colonnes ne contient :

- un mode, une ligne, une route, un arrêt ou un identifiant de section ;
- une zone tarifaire structurée ou une gare aéroportuaire ;
- une origine, une destination ou une matrice origine-destination ;
- une durée de correspondance, une règle de sortie du réseau ou un nombre de tickets ;
- un âge, un profil, un droit à réduction ou un abonnement détenu ;
- un plafond journalier ou un historique de consommation ;
- un statut commercial actif/retiré ou des dates d'effet.

Cette absence n'est pas compensée par le prix affiché : plusieurs produits demandent la même information de trajet mais répondent à des situations personnelles ou commerciales différentes. Les pages officielles montrent les règles que le tableau ne modélise pas :

| Produit actuel | Règles officielles utiles | Conséquence pour un itinéraire |
| --- | --- | --- |
| [Ticket Bus-Tram](https://www.iledefrance-mobilites.fr/titres-et-tarifs/detail/ticket-bus-tram) | 2,05 € plein tarif ; bus, tram, Tzen et Câble C1 ; correspondances pendant 1 h 30 ; rail exclu ; aéroports exclus | Plusieurs sections de surface peuvent consommer un seul ticket, mais une section ferrée appartient à une autre famille tarifaire |
| [Ticket Métro-Train-RER](https://www.iledefrance-mobilites.fr/titres-et-tarifs/detail/ticket-metro-train-rer) | 2,55 € plein tarif ; métro, RER et train ; correspondances pendant 2 h sans sortie ; bus/tram et gares ferrées aéroportuaires exclus | Les zones 1 à 5 ne changent plus le plein tarif unitaire, mais une sortie puis une nouvelle entrée ou une section de surface change le nombre de titres |
| [Ticket Paris Région <> Aéroports](https://www.iledefrance-mobilites.fr/titres-et-tarifs/detail/ticket-paris-region-aeroports) | 14 € ; Orly par la ligne 14 ou Orlyval, CDG par le RER B ; correspondances ferrées pendant 2 h ; bus/tram exclus | L'origine/destination et la desserte exacte comptent davantage que la seule présence d'un mode métro ou RER |
| [Navigo Liberté +](https://www.iledefrance-mobilites.fr/titres-et-tarifs/detail/liberte-plus) | 2,04 € en ferré, 1,64 € en surface, 14 € vers les aéroports, tarifs réduits et plafond quotidien au prix de Navigo Jour hors aéroports | Le catalogue ne conserve que `dès 1,64€` ; le coût facturé dépend du mode, du droit à réduction et des trajets déjà effectués dans la journée |
| [Navigo Jour](https://www.iledefrance-mobilites.fr/titres-et-tarifs/detail/forfait-navigo-jour) | 12,30 €, toutes zones, voyages illimités dans la journée, dessertes aéroportuaires exclues | C'est un achat de période, pas le prix marginal d'un trajet isolé |
| [Navigo Semaine](https://www.iledefrance-mobilites.fr/titres-et-tarifs/detail/forfait-navigo-semaine) et [Navigo Mois](https://www.iledefrance-mobilites.fr/titres-et-tarifs/detail/forfait-navigo-mois) | Plusieurs combinaisons de zones et périodes de dézonage ; le catalogue ne montre que le prix toutes zones | Il faut connaître le forfait réellement détenu, ses zones et la date du voyage ; les seules stations du trajet ne suffisent pas |

Même un trajet uniquement en bus a plusieurs prix possibles : le [ticket acheté à bord](https://www.iledefrance-mobilites.fr/titres-et-tarifs/detail/ticket-a-bord) coûte 2,55 € et ne donne aucune correspondance, tandis que le [ticket par SMS](https://www.iledefrance-mobilites.fr/titres-et-tarifs/detail/tab-sms) coûte 2,55 €, dure une heure, ne donne pas de correspondance et dépend de l'opérateur téléphonique. Un calculateur ne peut pas deviner le canal d'achat de la personne.

Le catalogue contient en outre deux produits de transition qui ne sont plus vendus : le [Ticket t+](https://www.iledefrance-mobilites.fr/titres-et-tarifs/detail/ticket-t) et le [Billet Origine-Destination](https://www.iledefrance-mobilites.fr/titres-et-tarifs/detail/billet-origine-destination). Leurs pages les annoncent utilisables jusqu'au 15 décembre 2026, mais aucune colonne du jeu ne porte ce statut ou cette échéance. Une sélection automatique des 29 lignes proposerait donc encore des produits retirés de la vente.

### Zones, modes et origine/destination

Depuis la tarification actuelle, les deux tickets unitaires ordinaires sont valables en zones 1 à 5 ; les zones ne déterminent donc plus leur prix plein tarif. Elles restent nécessaires pour savoir si un forfait Semaine, Mois ou Annuel à deux zones couvre le voyage. Le jeu ne fournit ni le zonage des arrêts ni les variantes tarifaires de ces forfaits.

Le mode seul ne suffit pas non plus. Un trajet métro + bus demande deux familles de tickets ; un trajet ferré vers Orly ou CDG utilise le titre aéroport ; une desserte spéciale peut avoir ses propres exclusions. Une heuristique locale devrait recréer toutes les règles de validation, de durée, de sortie, de service spécial et de cumul. Ce serait un moteur tarifaire séparé, pas une jointure au jeu `titres-et-tarifs`.

## Le tarif calculé par PRIM/Navitia

La [fiche API PRIM](https://prim.iledefrance-mobilites.fr/fr/apis/idfm-navitia-general-v2) décrit le calculateur authentifié déjà appelé par Via. La [documentation technique officielle](https://doc.navitia.io/#journeys) définit la réponse ainsi :

- chaque `journey.fare` contient `found`, un `total` et des liens vers les tickets ;
- `total.value` est un nombre décimal encodé comme chaîne ;
- `total.currency` reprend l'unité monétaire des données d'entrée ;
- la collection racine `tickets` contient pour chaque ticket un `id`, un `name`, `found`, un `cost` et des liens vers des sections.

Une réponse IDFM observée pour Châtelet → Nation portait par exemple :

```json
{
  "fare": {
    "found": true,
    "total": { "currency": "centime", "value": "255.0" },
    "links": [{ "id": "ticket_1", "rel": "tickets", "type": "ticket" }]
  }
}
```

Le calculateur IDFM utilise donc `centime`, pas un code ISO 4217, et encode la valeur comme texte décimal. Via doit accepter explicitement cette unité, valider une valeur finie et non négative, puis la normaliser en centimes d'euro entiers. Une unité inconnue doit rendre le tarif absent plutôt que provoquer une conversion implicite.

### Vérifications live du 29 août 2026

Les requêtes suivantes ont utilisé l'endpoint officiel `GET https://prim.iledefrance-mobilites.fr/marketplace/v2/navitia/journeys` avec l'en-tête `apikey`, `direct_path=none` et les identifiants/coordonnées indiqués. Les montants correspondaient aux pages tarifaires officielles le même jour.

| Itinéraire demandé | Sections renvoyées | `fare.total` | Tickets reliés au trajet |
| --- | --- | ---: | --- |
| Châtelet `stop_area:IDFM:71264` → Nation `stop_area:IDFM:71673` | Métro 1 | 255 centimes | Ticket Metro Train RER, 255 centimes |
| Centre de Paris `2.3522;48.8566` → Tour Eiffel `2.2945;48.8584` | Métro 1 + bus 80 | 460 centimes | Ticket Metro Train RER 255 + Ticket Bus Tram 205 |
| Mêmes coordonnées, alternative | Bus 72 seul | 205 centimes | Ticket Bus Tram, 205 centimes |
| Châtelet → Aéroport d'Orly `stop_area:IDFM:63284` | Métro 14 | 1 400 centimes | Ticket Paris Region<>Aeroports, 1 400 centimes |
| Châtelet → Aéroport CDG Terminal 2 `stop_area:IDFM:73699` | Métro 4 + RER B | 1 400 centimes | Ticket Paris Region<>Aeroports, 1 400 centimes |

Ces essais démontrent ce que le catalogue ne peut pas faire : le calculateur compte les familles de titres d'un itinéraire multimodal et applique l'exception aéroport à l'origine/destination exacte.

### Limites du champ `fare`

Le total reste un **tarif public indicatif**, pas le débit personnel certain :

- la requête Via ne transmet ni forfait possédé, ni zones souscrites, ni réduction, ni âge, ni consommation Liberté + du jour ;
- le calculateur ne peut donc pas savoir qu'un forfait couvre déjà le trajet, appliquer un droit personnel ou annoncer le montant final d'une facture plafonnée ;
- `fare.found: false` signifie explicitement qu'aucun tarif n'a été trouvé. Il ne faut jamais le transformer en zéro ;
- `fare` ne porte pas de date d'effet ni de version tarifaire. Les valeurs live correspondaient aux pages IDFM lors du test, mais cette concordance mérite un test sentinelle périodique ;
- les IDs `ticket_1`, `ticket_2`, etc. sont internes à une réponse et ne sont pas des clés de jointure avec le catalogue Open Data. Les noms diffèrent aussi typographiquement de `product_name` ;
- lors de plusieurs sondages Châtelet → Nation, un `ticket.links` a désigné `section_0_0` alors que les IDs de sections présents étaient suffixés autrement. Le total au niveau `journey` et le lien `journey.fare → ticket` étaient cohérents, mais l'annotation fine par section doit vérifier que la cible existe avant de l'utiliser.

Pour l'affichage demandé à côté du CO₂e, seul le total au niveau de l'itinéraire est nécessaire. Cela évite de dépendre du lien plus fragile entre ticket et section.

## Intégration recommandée dans Via

### Chemin nominal

Le client serveur [`idfm/client.ts`](../../apps/api/src/routers/journeys/idfm/client.ts) récupère déjà la réponse Navitia complète. Le total doit être extrait dans [`idfm/parse.ts`](../../apps/api/src/routers/journeys/idfm/parse.ts), transporté comme une valeur optionnelle au niveau de `Journey`, puis rendu dans l'en-tête de [`JourneyDetailHeaderView`](../../apps/via/via/Features/Journeys/Presentation/View/JourneyDetailHeaderView.swift), à côté de `journey.carbonEmission`.

Un contrat minimal suffit :

```text
JourneyFare
  amountInCents: entier >= 0
  currency: EUR

Journey
  fare: JourneyFare?
```

Conserver les centimes entiers évite les erreurs binaires de `Double`. Le formatage en euros appartient à l'iPhone et doit respecter la locale française. Le libellé visuel et VoiceOver recommandé est « Tarif plein indicatif » ; l'absence de valeur ne doit laisser ni tiret, ni `0 €`, ni état vide.

### Replis et mutations d'itinéraire

Le repli théorique local ne possède actuellement aucune donnée tarifaire dans le contrat ou les tables de transport : [`transit_stops`](../../packages/db/src/schema.ts) conserve l'identifiant, le nom et la position, sans zone, et aucune table n'importe les produits ou règles de tarif. Un trajet `gtfs-theoretical` doit donc rester sans tarif. Afficher un montant issu du catalogue sur ce chemin mélangerait une estimation heuristique avec le total officiel du chemin temps réel.

Le tarif appartient au **snapshot exact de l'itinéraire**. Il peut être conservé lors d'un simple décalage horaire qui garde les mêmes sections tarifaires. En revanche, si le choix d'un autre départ provoque un recalcul partiel, change une correspondance ou remplace l'aval du trajet, l'ancien total ne doit pas survivre et le tarif d'un sous-trajet aval ne doit pas être présenté comme celui du trajet composite. Il faut soit recalculer le trajet complet, soit effacer `fare`.

La même règle vaut pour les itinéraires partagés, les brouillons et le guidage actif : conserver la valeur avec l'itinéraire auquel elle appartient, puis l'omettre dès qu'une reconstruction locale rend sa provenance ambiguë.

### Usage résiduel du catalogue

Le jeu `titres-et-tarifs` peut servir ultérieurement à :

- ouvrir la page officielle d'un produit depuis une explication détaillée ;
- afficher une galerie éditoriale des titres disponibles ;
- surveiller les prix d'appel et déclencher une revue quand ils divergent de trajets sentinelles du calculateur.

Il ne doit pas être embarqué ou interrogé à chaque calcul d'itinéraire pour déterminer le total. Le chemin nominal `journey.fare` est à la fois plus précis et moins coûteux, puisqu'il voyage déjà dans la réponse PRIM.

## Sources primaires

- [PRIM — Titres et tarifs](https://prim.iledefrance-mobilites.fr/fr/jeux-de-donnees/titres-et-tarifs)
- [Open Data IDFM — fiche du jeu](https://data.iledefrance-mobilites.fr/explore/dataset/titres-et-tarifs/)
- [Open Data IDFM — métadonnées et schéma API](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/titres-et-tarifs)
- [Open Data IDFM — export JSON complet](https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/titres-et-tarifs/exports/json)
- [PRIM — Calculateur Île-de-France Mobilités, accès générique v2](https://prim.iledefrance-mobilites.fr/fr/apis/idfm-navitia-general-v2)
- [Navitia — documentation officielle des journeys et fares](https://doc.navitia.io/#journeys)
- [Île-de-France Mobilités — Ticket Bus-Tram](https://www.iledefrance-mobilites.fr/titres-et-tarifs/detail/ticket-bus-tram)
- [Île-de-France Mobilités — Ticket Métro-Train-RER](https://www.iledefrance-mobilites.fr/titres-et-tarifs/detail/ticket-metro-train-rer)
- [Île-de-France Mobilités — Ticket Paris Région <> Aéroports](https://www.iledefrance-mobilites.fr/titres-et-tarifs/detail/ticket-paris-region-aeroports)
- [Île-de-France Mobilités — Navigo Liberté +](https://www.iledefrance-mobilites.fr/titres-et-tarifs/detail/liberte-plus)
- [data.gouv.fr — Licence Ouverte 2.0](https://www.data.gouv.fr/pages/legal/licences/etalab-2.0)
