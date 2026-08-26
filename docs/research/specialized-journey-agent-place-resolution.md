# Agent spécialisé de trajet : compréhension et résolution typée des lieux

- Date : 2026-08-26
- Statut : recherche suivie d’une implémentation générique des priorités P0, P1, P4 et P5
- Périmètre : langage naturel, distinction station/gare/commune/adresse, choix d’architecture OpenAI, données Apple et Île-de-France Mobilités
- Sources externes : documentation primaire et officielle uniquement

## Conclusion

Via ne repose déjà **pas** sur un chat générique auquel on aurait seulement ajouté une phrase. Le chemin nominal effectue une interprétation spécialisée, structurée et sans outils dans la Responses API, valide chaque fragment contre la saisie, puis laisse l’app résoudre les lieux et planifier. C’est cohérent avec l’ADR acceptée : **ancrage → interprétation typée → fusion/validation → résolution des lieux → planification** ([ADR-0005](../adr/0005-reliable-natural-journey-understanding.md#décision)).

Le défaut observé vient surtout de quatre trous de contrat :

1. `query("Bonne Nouvelle")` ne dit pas si le fragment désigne une station, une commune ou une adresse ;
2. les communes sont encore transportées comme des adresses et leur distinction de type est perdue dans la réponse publique de recherche ;
3. le parseur déterministe reconnaît les couples avec marqueurs (« de X à Y »), pas un couple sans préposition comme « Chatou Bonne Nouvelle » ;
4. une réponse courte à une clarification (« D’où pars-tu ? » → « Chatou ») ne transporte pas explicitement le champ attendu jusqu’à l’interpréteur.

Installer l’Agents SDK ne corrigerait aucun de ces quatre points. La documentation OpenAI distingue la Responses API, adaptée quand l’application garde la main sur les interactions, outils, états et branchements, de l’Agents SDK, utile quand le SDK doit exécuter une boucle récurrente, des handoffs entre spécialistes, des validations ou des approbations ([OpenAI, Agents SDK vs Responses API](https://developers.openai.com/api/docs/guides/agents#agents-sdk-vs-responses-api)). Le workflow nominal de Via est une extraction bornée en un appel et une orchestration déterministe déjà possédée par l’app : **conserver la Responses API est le choix recommandé**.

La priorité est donc de spécialiser le **contrat des lieux et son moteur de résolution**, non de rendre le modèle plus autonome.

## État d’implémentation au 26 août 2026

L’implémentation issue de cette recherche est intégrée dans le dépôt. Elle ne
contient aucune table de correspondance par nom de lieu : les mêmes règles sont
appliquées à chaque saisie et à chaque candidat du catalogue.

- le champ clarifié (`origin`, `destination` ou `time`) survit au retour dans le compositeur et accompagne la révision ;
- une réponse courte comme « Chatou » hérite déterministement de ce champ au lieu de redemander au modèle son rôle ;
- le résolveur extrait une préférence `transit`, `address` ou `locality` des mots de l’utilisateur ; un type explicite ferme le catalogue admissible, donc une demande de station ne peut jamais retomber sur une adresse et réciproquement ;
- les préfixes transport sont une grammaire composable (`station RER`, `station de tram`, `arrêt de bus`, etc.), indépendante du nom qui suit ;
- une gare est d’abord cherchée sous son nom canonique complet (`Gare de Lyon`, `Gare du Nord`, etc.), puis seulement sous la forme sans qualifiant si la première recherche échoue ou reste faible ;
- pour un nom nu, le prior transport privilégie une station rapide exacte ou l’unique station rapide portant le préfixe de la commune face aux arrêts de bus secondaires ;
- les saisies nues sont d’abord vérifiées comme un lieu complet, puis chaque frontière de tokens est testée contre le catalogue ; une paire n’est acceptée que si une seule segmentation produit deux correspondances fortes ;
- la recherche SQL tolère les espaces, tirets et apostrophes entre tokens, ce qui réconcilie notamment « Gare Saint Lazare » avec `Gare Saint-Lazare` ;
- le corpus versionné contient les exemples signalés, mais aussi des contre-exemples indépendants (`Gare de Lyon`, `Auber`, `République`, `La Défense → Porte de Versailles`) et une matrice multi-mode afin de tester les invariants plutôt que des noms particuliers.

La prochaine couche d’ontologie complète reste l’exposition d’un vrai `city` dans le contrat public, puis l’index d’alias humains et le score avec marge décrit plus bas. L’implémentation actuelle sait déjà sélectionner explicitement un centre-ville, mais le transporte encore dans le type historique `address`.

## Diagnostic du dépôt avant correction

| Constat | Preuve dans le dépôt | Conséquence |
|---|---|---|
| Le serveur nominal est un interprète stateless, sans recherche ni planification. | [`service.ts`](../../apps/api/src/routers/natural-journeys/service.ts#L64-L68), appel Responses avec `tools: []`, schéma strict et `store: false` ([lignes 128–140](../../apps/api/src/routers/natural-journeys/service.ts#L128-L140)). | Le modèle ne peut pas inventer ou sélectionner une adresse ; c’est une bonne frontière d’autorité. |
| Le prompt est déjà explicitement spécialisé transports franciliens et parsing sémantique. | [`prompt.ts`](../../apps/api/src/routers/natural-journeys/prompt.ts#L11-L37). | Le problème n’est pas l’absence d’une persona spécialisée. |
| La sortie OpenAI est un JSON Schema strict, puis validée avec Zod et avec des preuves textuelles. | [`prompt.ts`](../../apps/api/src/routers/natural-journeys/prompt.ts#L103-L168), [`service.ts`](../../apps/api/src/routers/natural-journeys/service.ts#L178-L292). | La forme de la réponse est robuste ; sa taxonomie de lieux reste trop pauvre. |
| Un lieu n’a que quatre formes : position, lieu enregistré, requête libre, référence conversationnelle. | [`RoutePlaceIntent`](../../apps/via/via/Features/NaturalJourneys/Domain/NaturalJourneyModels.swift#L45-L53) et schéma serveur [`PLACE_REFERENCE_JSON_SCHEMA`](../../apps/api/src/routers/natural-journeys/prompt.ts#L39-L51). | `Bonne Nouvelle`, `Balard`, `Chatou` et `12 rue…` finissent tous dans le même `query`. |
| Le tour de dialogue ne porte pas le champ auquel l’utilisateur répond. | [`NaturalJourneyTurn`](../../apps/via/via/Features/NaturalJourneys/Domain/NaturalJourneyUnderstanding.swift#L78-L103) contient phrase, locale, date et disponibilité de position ; le message serveur ne contient que les ancres et la saisie ([`buildUserMessage`](../../apps/api/src/routers/natural-journeys/service.ts#L317-L325)). | Après « D’où pars-tu ? », « Chatou » peut encore être interprété comme une destination implicite plutôt que comme l’origine attendue. |
| Le grounder reconnaît les couples avec marqueurs, puis les destinations marquées ou commandées. | [`routePair`](../../apps/via/via/Features/NaturalJourneys/Data/ReliableNaturalJourneyUnderstanding.swift#L736-L769), [`destinationThenOriginPair`](../../apps/via/via/Features/NaturalJourneys/Data/ReliableNaturalJourneyUnderstanding.swift#L771-L803), sélection des règles ([lignes 541–560](../../apps/via/via/Features/NaturalJourneys/Data/ReliableNaturalJourneyUnderstanding.swift#L541-L560)). | Aucun découpage déterministe et fondé par le catalogue pour « Chatou Bonne Nouvelle ». |
| Le résolveur actuel choisit « stations sauf si la chaîne ressemble à une adresse », puis exige un exact/unique proche. | [`OnDevicePlaceResolver`](../../apps/via/via/Features/NaturalJourneys/Data/OnDevicePlaceResolver.swift#L27-L54). | Le prior station est utile, mais une regex binaire ne sait pas représenter une commune ni exploiter une intention explicite « gare/station/métro ». |
| La recherche unifiée produit des stations et adresses, tandis que les communes sont gardées à part. | [`searchPlaces`](../../apps/api/src/routers/search/search-places.ts#L58-L117). | La donnée existe partiellement mais n’atteint pas le domaine iOS. |
| Le handler public ne sérialise pas le tableau séparé `municipalities`. La même feature BAN reste bien présente dans `results` via `toAddressResults`, mais sous `kind=address`. | [`search-places.ts`](../../apps/api/src/routers/search/search-places.ts#L102-L115), [`query-search.ts`](../../apps/api/src/routers/search/handlers/query-search.ts#L18-L35). | « centre-ville de Chatou » peut atteindre la bonne coordonnée, mais le domaine et l’interface ne peuvent pas l’identifier comme une commune plutôt que comme une adresse. |
| Une commune reste encodée dans le contrat comme une adresse. | [`toMunicipalityResults`](../../apps/api/src/routers/search/ban-mappers.ts#L41-L49), [`SearchResult`](../../apps/via/via/Features/Search/Domain/SearchModels.swift#L108-L168). | L’interface et le résolveur ne peuvent pas expliquer « gare ou centre-ville ? ». |
| Le classement inter-source place les stations avant les lieux sauf si la requête commence par un chiffre. | [`merge.ts`](../../apps/api/src/routers/search/merge.ts#L11-L32). | Le produit a déjà le bon prior transit, mais pas un score typé et explicable. |
| La recherche station porte seulement sur le nom canonique, puis préfixe/position/distance. | [`queries.ts`](../../apps/api/src/routers/search/queries.ts#L17-L82). | Aucun alias lexical, nom de commune, préfixe « gare de », ou classe de station n’aide le classement. |
| L’import GTFS replie les quais vers la station parente, mais ses « alias » ne sont que des identifiants source. | [`import-gtfs.ts`](../../apps/worker/src/import-gtfs.ts#L201-L226), [`import-gtfs.ts`](../../apps/worker/src/import-gtfs.ts#L288-L315), schéma [`transitStopAliases`](../../packages/db/src/schema.ts#L119-L129). | L’identité transport est solide ; il manque un index d’appellations humaines. |
| Les tests couvrent Nation face aux adresses et Gare Saint-Lazare face à la rue, mais pas les exemples signalés. | [`OnDevicePlaceResolverTests.swift`](../../apps/via/viaTests/OnDevicePlaceResolverTests.swift#L20-L43) ; le corpus critique couvre surtout les rôles avec prépositions ([`NaturalJourneyCriticalCorpusTests.swift`](../../apps/via/viaTests/NaturalJourneyCriticalCorpusTests.swift#L7-L29)). | « Bonne Nouvelle », « Balard », « Chatou » et « Chatou Bonne Nouvelle » ne sont pas des gates de régression aujourd’hui. |

## Architecture cible

```text
phrase + champ attendu + état verrouillé
                │
                ▼
   ancrage et segmentation déterministes
                │
                ▼
  interprétation typée des mentions de lieux
     (rôle + fragment + préférence de type)
                │
                ▼
 recherche de candidats par voies séparées
 station IDFM │ commune │ adresse │ lieu enregistré
                │
                ▼
 classement explicable + seuil d’abstention
                │
       ┌────────┴────────┐
       ▼                 ▼
 candidat unique    clarification ciblée
       │                 │
       └────────┬────────┘
                ▼
  verrouillage de l’identifiant confirmé
                │
                ▼
        planificateur déterministe
```

Cette architecture conserve une séparation essentielle :

- le **modèle** extrait ce que la personne a formulé ;
- le **catalogue et les règles** disent à quel objet réel cela correspond ;
- l’**état de dialogue** se souvient du champ attendu et des identifiants confirmés ;
- le **planificateur** ne reçoit jamais un nom libre quand un identifiant a déjà été résolu.

### 1. Enrichir la mention, pas laisser le modèle choisir un lieu

Le contrat d’interprétation devrait ajouter une préférence de type non autoritaire :

```text
PlaceMention
  surface: String                 // fragment exact de la phrase
  kindHint: auto | station | city | address
  evidence: String                // fragment exact, validé par Via

NaturalJourneyTurn
  expectedSlot: none | origin | destination
```

`origin` et `destination` restent les champs de rôle ; `kindHint` décrit seulement la classe demandée. Le résolveur, et jamais le modèle, retourne ensuite un `ResolvedPlace` :

```text
ResolvedPlace
  id: stable source identifier
  kind: station | cityCenter | address | savedPlace | currentLocation
  canonicalName: String
  coordinate: Coordinate
  source: idfm | geocoder | saved | device
  stationModes: [metro | rer | transilien | tram | bus]  // si pertinent
```

Règles recommandées :

- « station Bonne Nouvelle », « métro Balard », « gare de X », « RER X » donnent `kindHint=station` ;
- un numéro suivi d’un type de voie donne `kindHint=address` ;
- « ville/commune/centre de Chatou » donne `kindHint=city` ;
- un nom nu reste `auto`, afin que le catalogue puisse appliquer le prior d’une app de transports sans transformer une supposition du modèle en vérité ;
- si `expectedSlot=origin`, une réponse courte comme « Chatou » remplit uniquement l’origine ; si `expectedSlot=destination`, elle remplit uniquement la destination ;
- une correction explicite conserve la règle actuelle : elle ne déverrouille que le champ visé.

Le format strict garantit la conformité structurelle, pas la justesse du candidat réel. OpenAI précise que Structured Outputs assure l’adhérence au schéma, contrairement au simple JSON mode ([documentation Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs#structured-outputs-vs-json-mode)). Apple décrit de même la guided generation comme une génération contrainte empêchant les sorties mal formées ([documentation Foundation Models](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation)). Dans les deux cas, l’identité géographique doit donc rester validée par Via.

### 2. Donner une vraie ontologie à la recherche

La réponse de recherche devrait exposer les communes comme `kind=city`, au lieu de les cacher dans `municipalities` puis de les perdre. Les candidats doivent conserver au minimum : type, nom canonique, commune/contexte, modes desservis, identifiant de station et source.

Pour les stations, utiliser comme objet cible l’arrêt commercial / zone d’arrêt, pas un quai. La documentation PRIM décrit un `stop_area` comme le regroupement d’arrêts physiques portant le même nom commercial ([documentation fonctionnelle Navitia, pages 8–9](https://prim.iledefrance-mobilites.fr/content/files/2024/04/-FR--Documentation-fonctionnelle-PRIM---Prise-en-main-des-API-Navitia.pdf)). C’est cohérent avec le repli actuel des quais GTFS vers leur `parent_station`.

Ajouter un index d’appellations humaines distinct des alias d’identifiants :

- nom commercial IDFM normalisé ;
- variantes accent/tiret/apostrophe ;
- variante contrôlée avec ou sans « gare », « station », « métro », « RER » ;
- commune et modes comme métadonnées de désambiguïsation ;
- alias éditoriaux explicites et sourcés lorsque le nom spontané diffère du nom du flux.

Le jeu IDFM « Zones d’arrêts » décrit précisément des zones monomodales cohérentes commercialement et connues du public sous la même appellation ([source officielle IDFM](https://data.iledefrance-mobilites.fr/explore/dataset/zones-d-arrets/)). Le référentiel NeTEx distingue notamment gare ferroviaire, station de métro, station de tramway, gare routière et arrêt de bus ([document d’interface officiel IDFM](https://data.iledefrance-mobilites.fr/api/v2/catalog/datasets/referentiels-lignes-arrets-offre-netex/attachments/referentiel_des_arrets_netex_v1_pdf)). Ces sources peuvent enrichir le type et les alias sans déléguer la vérité au LLM.

Le GTFS IDFM déjà importé par Via reste la base canonique de planification : le jeu officiel agrège l’offre des différents modes franciliens et est publié régulièrement ([jeu GTFS PRIM](https://prim.iledefrance-mobilites.fr/jeux-de-donnees/offre-horaires-tc-gtfs-idfm)).

### 3. Remplacer la bifurcation binaire par un score typé

Chaque candidat devrait recevoir des composantes observables, par exemple :

1. correspondance exacte du nom canonique ;
2. correspondance exacte d’un alias ;
3. compatibilité avec `kindHint` ;
4. prior transport lorsque `kindHint=auto` ;
5. compatibilité commune/mode explicitement citée ;
6. distance, uniquement comme départage et non comme réécriture du sens ;
7. qualité et fraîcheur de la source.

La décision doit dépendre d’un seuil absolu **et** de l’écart entre les deux meilleurs scores :

- un candidat fort et nettement séparé est résolu ;
- deux candidats proches produisent une clarification présentant le type et le contexte (« station » / « centre de la commune » / « adresse ») ;
- aucun candidat fort produit `notFound`, sans promouvoir arbitrairement une rue.

Ne pas demander au modèle un nombre de confiance : ce score est une propriété du résolveur et de ses preuves, donc reproductible et évaluable.

### 4. Segmenter « Chatou Bonne Nouvelle » avec le catalogue

Ajouter avant le modèle une règle de couple sans préposition, activée seulement si le catalogue la fonde :

1. normaliser la saisie ;
2. tester les frontières entre tokens ;
3. rechercher chaque moitié dans l’index stations/communes/adresses ;
4. scorer chaque paire avec les mêmes preuves typées ;
5. accepter uniquement une paire forte, unique et nettement séparée ;
6. affecter la moitié gauche à l’origine et la moitié droite à la destination ;
7. sinon demander une clarification ciblée, sans inventer un découpage.

Pour « Chatou Bonne Nouvelle », la frontière `Chatou | Bonne Nouvelle` doit l’emporter seulement si les deux moitiés produisent de vrais candidats forts. Cette règle évite une heuristique fragile « couper au milieu » et fonctionne aussi avec des noms multi-mots. Pour éviter plusieurs appels réseau, le découpage peut utiliser un index lexical de stations mis en cache, ou une résolution batch possédée par Via.

Comportements produits attendus :

| Saisie/contexte | Comportement attendu |
|---|---|
| « Bonne Nouvelle » | destination = station si le nom commercial exact est unique ; pas une adresse homonyme |
| « Balard » | destination = station si le nom commercial exact est unique |
| « station Balard » | voie station obligatoire ; ne jamais proposer une adresse |
| « 12 rue de Rivoli » | voie adresse obligatoire |
| Question « D’où pars-tu ? » puis « Chatou » | `expectedSlot=origin`; proposer la gare/station exacte si unique, ou une clarification « gare ou centre de Chatou ? » si les deux politiques restent plausibles |
| « Chatou Bonne Nouvelle » | origine `Chatou`, destination station `Bonne Nouvelle`, uniquement après segmentation fondée par le catalogue |

### 5. Garder la logique conditionnelle hors du modèle local

Apple recommande des prompts courts et spécifiques, de réduire le raisonnement demandé, de tester continuellement et de convertir les conditionnels trop complexes en logique de programmation ([Prompting an on-device foundation model](https://developer.apple.com/documentation/foundationmodels/prompting-an-on-device-foundation-model)). Cela confirme l’orientation existante de Via : marqueurs de rôle, champ attendu, segmentation cataloguée, ranking et verrouillage doivent vivre en Swift/TypeScript ; le modèle local intervient sur le résidu réellement linguistique.

## Choix OpenAI

### Responses API + Structured Outputs : conserver

OpenAI propose Structured Outputs sous deux formes : function calling pour relier le modèle aux fonctions/données de l’application, et `text.format` pour obtenir une réponse structurée ([guide officiel](https://developers.openai.com/api/docs/guides/structured-outputs#when-to-use-structured-outputs-via-function-calling-vs-via-textformat)). Le chemin nominal de Via demande un patch sémantique, sans action : son `text.format` strict et `tools: []` est donc approprié.

Compléments à conserver ou ajouter :

- garder `store: false` ; OpenAI indique que les Response objects sont conservés 30 jours par défaut et que ce paramètre désactive cette conservation ([Conversation state — data retention](https://developers.openai.com/api/docs/guides/conversation-state#data-retention-for-model-responses)) ;
- garder l’état typé dans l’app plutôt que d’utiliser la conversation fournisseur comme source de vérité ;
- normaliser séparément un refus et une sortie incomplète. OpenAI précise qu’un refus peut ne pas respecter le schéma fourni et est signalé dans un champ `refusal` ([Structured Outputs — refusals](https://developers.openai.com/api/docs/guides/structured-outputs#refusals-with-structured-outputs)). Le transport actuel ne conserve que `output_text`, appels de fonction et usage ([`openai-transport.ts`](../../apps/api/src/routers/natural-journeys/openai-transport.ts#L87-L115)), ce qui transforme ce cas en simple `invalid-output` ;
- choisir modèle et effort de raisonnement par corpus mesuré, pas parce qu’un modèle est présenté comme plus « agentique ».

### Agents SDK : ne pas migrer maintenant

OpenAI définit un agent comme une application qui planifie, appelle des outils, collabore entre spécialistes et conserve assez d’état pour un travail multiétape ([Agents SDK](https://developers.openai.com/api/docs/guides/agents)). Le SDK devient pertinent si Via ajoute réellement :

- une boucle récurrente d’appels d’outils ;
- plusieurs spécialistes avec handoffs ;
- des guardrails/approbations qui suspendent puis reprennent un run ;
- le besoin assumé des sessions et traces intégrées du SDK.

Il n’est pas nécessaire pour un parseur spécialisé en un appel. Une migration aujourd’hui ajouterait une seconde boucle d’orchestration sans enrichir la taxonomie des lieux ni le catalogue.

Le dépôt contient bien une ancienne boucle outils ([`agent.ts`](../../apps/api/src/routers/natural-journeys/agent.ts#L51-L155)), mais l’ADR la qualifie de chemin historique de rollback, non nominal ([ADR-0005](../adr/0005-reliable-natural-journey-understanding.md#conséquences)). Si elle reste testable, ses outils devraient passer de `strict: false` ([`tools.ts`](../../apps/api/src/routers/natural-journeys/tools.ts#L116-L135)) à `strict: true` après adaptation des schémas : OpenAI recommande toujours le strict mode et exige `additionalProperties: false` ainsi que tous les champs marqués requis, les valeurs facultatives devant par exemple être représentées par un type nullable ([Function calling — strict mode](https://developers.openai.com/api/docs/guides/function-calling#strict-mode)). Si un tour ne doit jamais exécuter deux actions, `parallel_tool_calls: false` impose zéro ou un appel ([Function calling — parallel calls](https://developers.openai.com/api/docs/guides/function-calling#parallel-function-calling)). Cela reste une mesure d’entretien du rollback, pas la solution aux cas signalés.

## Place d’Apple MapKit et de PRIM

### IDFM/PRIM : autorité transport

La priorité recommandée est :

1. GTFS/référentiels IDFM pour l’identité canonique et le type d’arrêt ;
2. géocodeur actuel pour adresse et commune, avec deux kinds distincts ;
3. endpoint PRIM Navitia `/places` en comparaison silencieuse ou secours évalué, pas comme seconde vérité activée sans mapping d’identifiants.

La documentation PRIM inclut explicitement recherche de lieux, exploration réseau et recherche d’itinéraires, et documente la route v2 `/marketplace/v2/navitia/places?q=…` ([documentation fonctionnelle officielle](https://prim.iledefrance-mobilites.fr/content/files/2024/04/-FR--Documentation-fonctionnelle-PRIM---Prise-en-main-des-API-Navitia.pdf)). Via peut donc comparer ses résultats à PRIM sur un corpus, puis décider avec des mesures de rappel, stabilité d’identifiants et latence.

### MapKit : secours iOS ciblé, pas identité canonique

MapKit permet de filtrer les types de résultats d’une recherche et d’une autocomplétion ([`MKLocalSearch.Request.resultTypes`](https://developer.apple.com/documentation/mapkit/mklocalsearch/request/resulttypes), [`MKLocalSearchCompleter.resultTypes`](https://developer.apple.com/documentation/mapkit/mklocalsearchcompleter/resulttypes)), distingue notamment les résultats adresse ([`.address`](https://developer.apple.com/documentation/mapkit/mklocalsearch/resulttype/address)) et expose la catégorie de point d’intérêt transport public ([`.publicTransport`](https://developer.apple.com/documentation/mapkit/mkpointofinterestcategory/publictransport)).

Par inférence de contrat, cette catégorie générique peut améliorer un secours de découverte sur l’iPhone, mais ne remplace pas directement l’identité `StationID` attendue par Via : un résultat MapKit devrait être remappé vers un arrêt IDFM avant planification. Le lancer en voie parallèle station/adresse est préférable à une recherche unique puis à une devinette sur le type.

## Évaluations et observabilité

### Corpus à ajouter avant toute modification de prompt

Créer des tests bout en bout qui séparent cinq objectifs : segmentation, rôle, type, identifiant canonique, décision de clarification.

| Tranche | Exemples minimaux | Assertions exactes |
|---|---|---|
| Station nue | « Bonne Nouvelle », « Balard », « Nation » | destination, `kind=station`, identifiant station attendu |
| Préfixe transport | « station Balard », « métro Bonne Nouvelle », « Gare Saint-Lazare » | aucune adresse admissible |
| Commune/gare | « Chatou », « Saint-Germain-en-Laye » | candidat station ou ville selon politique documentée ; jamais une rue arbitraire |
| Couple sans marqueur | « Chatou Bonne Nouvelle », « Chatou Balard », un départ multi-mots vers Bonne Nouvelle | frontière, origine, destination, kinds et IDs exacts |
| Adresse explicite | « 12 rue de Rivoli », « place de la Nation » | voie adresse, pas station |
| Réponse à clarification | « D’où pars-tu ? » → « Chatou » ; « Où veux-tu aller ? » → « Balard » | seul le `expectedSlot` change |
| Variantes vocales | accents, tirets, apostrophes, petite faute ASR | même ID ou clarification déterministe |
| Corrections | « non, depuis Chatou » après un trajet confirmé | origine seule modifiée, destination verrouillée |

Mesures à rapporter par tranche et par chemin déterministe/local/serveur :

- exactitude du rôle origine/destination ;
- exactitude de segmentation ;
- exactitude du kind ;
- exactitude de l’identifiant canonique ;
- taux de clarification correcte ;
- taux d’inversion, de fausse résolution et de sur-clarification ;
- latence de résolution et nombre de candidats examinés.

Conserver les gates ADR de 100 % sur le corpus critique et 99 % sur le général, en faisant des cas station/commune et couple sans marqueur une tranche critique ([ADR-0005](../adr/0005-reliable-natural-journey-understanding.md#décision)).

OpenAI recommande des évaluations propres à la tâche, représentatives de la distribution réelle, automatisées quand possible, calibrées avec du jugement humain et exécutées continuellement ([Evaluation best practices](https://developers.openai.com/api/docs/guides/evaluation-best-practices#what-are-evals)). Pour les workflows SDK, les traces capturent appels de modèle, outils, guardrails et handoffs, puis le trace grading permet d’assigner des scores structurés ([Evaluate agent workflows](https://developers.openai.com/api/docs/guides/agent-evals), [Trace grading](https://developers.openai.com/api/docs/guides/trace-grading)).

Attention au calendrier actuel : OpenAI annonce la mise en lecture seule de la plateforme Evals historique le 31 octobre 2026 et son arrêt le 30 novembre 2026 ([avis officiel](https://developers.openai.com/api/docs/guides/evaluation-best-practices)). Le corpus XCTest/Bun versionné doit rester la source de vérité ; ne pas construire cette amélioration autour de l’ancienne Evals API.

Pour respecter la décision de confidentialité existante, les métriques de production devraient garder seulement : version, chemin, kind choisi, nombre de candidats, écart de score, clarification oui/non, résultat et latence. Pas de phrase brute. Une trace détaillée contenant la saisie ne devrait exister qu’après le mécanisme volontaire et prévisualisé déjà prévu par l’ADR.

## Ordre d’implémentation recommandé

1. **P0 — Reproduction et gates** : ajouter les cas ci-dessus au corpus avant de toucher au comportement.
2. **P1 — Contexte de dialogue** : transmettre `expectedSlot` pour qu’une réponse courte complète le champ demandé.
3. **P2 — Ontologie** : ajouter `kindHint` à la sortie locale/serveur et un vrai `city` au contrat de recherche.
4. **P3 — Catalogue** : indexer alias humains, commune et type/modes à partir des sources IDFM ; conserver l’identifiant commercial canonique.
5. **P4 — Résolveur** : score typé, seuil + écart, clarifications montrant la classe du candidat.
6. **P5 — Couple sans marqueur** : segmentation fondée par le catalogue, avec abstention si plusieurs découpages restent plausibles.
7. **P6 — Comparaisons** : tester PRIM `/places` et éventuellement MapKit en shadow/fallback avant toute activation.
8. **P7 — Prompt** : seulement après les couches précédentes, ajouter quelques exemples ciblés au parseur et comparer les modèles/efforts sur le même corpus.

La définition de succès est simple : **« Bonne Nouvelle » et « Balard » deviennent des stations par preuve de catalogue ; « Chatou » devient une gare ou un centre de commune selon une politique explicite ; « Chatou Bonne Nouvelle » devient un couple origine/destination par segmentation déterministe ; aucune de ces décisions n’est laissée à une réponse plausible du modèle.**
