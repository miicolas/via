# Architecture fiable pour la recherche naturelle de trajets

- Date : 2026-08-26
- Périmètre : application iOS Via, interprétation locale Apple Foundation Models et repli OpenAI
- Question de départ : comment rendre fiables des demandes comme « rentrez chez moi depuis Auber », y compris les corrections conversationnelles, les lieux personnels et les ambiguïtés ?

## Conclusion

Via ne doit pas construire un agent autonome chargé d'interpréter, rechercher des lieux et planifier. Le bon système est un **interpréteur de dialogue orienté tâche** : il transforme chaque tour en une modification typée d'un état de trajet, puis du code déterministe valide, résout les lieux et calcule l'itinéraire.

Le modèle reste utile pour les formulations variées et implicites, mais il ne devient jamais l'autorité des lieux, des rôles origine/destination, du temps ou des trajets. Il produit une proposition structurée et ancrée dans la phrase. Le domaine Via accepte, corrige par règle explicite, demande une clarification ou s'abstient.

Cette architecture confirme le design issu du grilling :

1. extraction déterministe des faits critiques ;
2. une seule génération guidée locale pour ce qui reste ;
3. repli serveur limité à la même extraction structurée ;
4. un état de dialogue typé mis à jour par patch ;
5. résolution des lieux et planification hors modèle ;
6. confiance calculée à partir de preuves vérifiables, jamais déclarée par le modèle ;
7. corpus de non-régression par capacité et abstention contrôlée.

## 1. Le problème est du semantic parsing, pas un chat généraliste

La littérature sur les dialogues orientés tâche représente l'objectif de la personne sous forme d'intentions et de slots, puis maintient cet état entre les tours. Le jeu Schema-Guided Dialogue formalise précisément les tâches de compréhension, remplissage de slots et suivi d'état ; il sépare ce schéma de la génération de réponse ([Rastogi et al., 2020](https://arxiv.org/abs/1909.05855)). Les travaux comparatifs sur le dialogue state tracking rappellent que les représentations par frames restent le modèle courant pour les intentions et valeurs de slots ([Cao et Zhang, 2021](https://aclanthology.org/2021.naacl-main.62/)).

Pour Via, le frame canonique est petit et stable :

- origine ;
- destination ;
- date/heure et sens départ/arrivée ;
- ancre de service, par exemple dernier départ ;
- modes requis, préférés et exclus ;
- contraintes non prises en charge ;
- provenance et preuve textuelle de chaque valeur ;
- statut de confirmation de chaque champ.

Une correction comme « plutôt vers 19 h » ne doit donc pas relancer une conversation libre. Elle produit un patch ciblé sur le slot temporel. « Non, depuis Opéra » remplace uniquement l'origine. Cette stratégie préserve les faits déjà confirmés et rend chaque transition testable.

### Conséquence pour Via

Le module profond doit présenter une interface de type `interpret(turn, state) -> transition`. Il cache l'extraction déterministe, l'adapter Foundation Models, l'adapter serveur, la fusion, la validation et la politique d'abstention. La recherche de lieux et le calcul d'itinéraires restent après cette interface.

## 2. Les sorties contraintes règlent la forme, pas la vérité

Apple décrit `@Generable` et `@Guide` comme le moyen de générer des structures Swift par constrained sampling, plutôt que de parser une réponse textuelle ([Apple, Guided Generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation)). OpenAI Structured Outputs garantit de son côté l'adhérence à un JSON Schema et expose les refus séparément ([OpenAI, Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs)). La documentation OpenAI recommande également le mode strict pour les appels de fonctions ([OpenAI, Function calling — strict mode](https://developers.openai.com/api/docs/guides/function-calling#strict-mode)).

Ces garanties empêchent une clé manquante ou une valeur d'enum invalide. Elles ne prouvent pas qu'« Auber » est bien l'origine, que « chez moi » désigne le domicile enregistré, ni que le texte généré est présent dans la phrase. Le validateur du domaine reste indispensable.

Chaque valeur générée critique doit donc transporter :

- sa valeur proposée ;
- un fragment de preuve copié de l'entrée ;
- son rôle proposé ;
- sa provenance (`deterministic`, `localModel`, `serverModel`, `confirmed`, `context`) ;
- son état (`proposed`, `grounded`, `confirmed`).

Le validateur vérifie que la preuve appartient à la phrase, qu'elle ne chevauche pas un fait verrouillé de façon contradictoire, que les rôles sont cohérents avec les ancres syntaxiques et que les contraintes du domaine sont satisfaites.

## 3. Les faits explicites doivent être extraits avant le modèle

Apple présente le modèle embarqué comme adapté notamment à l'extraction d'entités, mais recommande de réduire le raisonnement demandé, de transformer les conditionnelles en logique de programme et de commencer par une requête simple ([Apple, Prompting an on-device foundation model](https://developer.apple.com/documentation/foundationmodels/prompting-an-on-device-foundation-model)).

La recherche sur les systèmes orientés tâche montre également l'importance de confronter les slots aux connaissances externes. Des combinaisons syntaxiquement valides peuvent être impossibles dans le domaine ; une validation tardive laisse les erreurs s'accumuler ([Lertvittayakumjorn et al., 2021](https://aclanthology.org/2021.naacl-main.266/)).

Via doit donc extraire et verrouiller avant tout appel modèle :

- les lieux personnels explicitement nommés (`chez moi`, `home`, `au travail`, alias enregistrés) ;
- les patrons non ambigus `de X à Y`, `depuis X vers Y`, `destination personnelle depuis X` ;
- les heures et dates écrites dans les syntaxes déjà couvertes ;
- les modes explicitement requis ou exclus ;
- les références à un slot confirmé du tour précédent.

Le modèle reçoit ensuite la phrase, le schéma et ces ancres immuables. Il ne doit remplir que les champs manquants ou signaler une contradiction. Une demande dont tous les champs critiques sont résolus et dont aucun fragment significatif ne reste inexpliqué contourne entièrement le modèle.

### Cas de référence

`rentrez chez moi depuis Auber` devient, avant modèle :

```text
origin      = publicPlace(query: "Auber")
destination = savedPlace(role: home)
time        = now, departure
evidence    = "depuis Auber" / "chez moi"
```

Le résolveur local remplace ensuite `home` par le `SavedPlace` réel et recherche uniquement Auber. La chaîne « chez moi » ne part jamais au géocodeur.

## 4. Le repli serveur doit être un adapter d'interprétation

Le serveur actuel est un agent à outils : il recherche les lieux puis planifie. Cette boucle duplique la politique locale et laisse le modèle choisir entre des candidats. Les capacités de function calling et d'appels parallèles d'OpenAI sont utiles lorsqu'un modèle doit réellement orchestrer des outils ([OpenAI, Function calling](https://developers.openai.com/api/docs/guides/function-calling)), mais Via n'a pas besoin de déléguer cette autorité : ses modules de recherche et de planification existent déjà.

Le repli recommandé effectue un unique appel Responses API avec un Structured Output strict. Son entrée contient :

- la phrase ;
- la locale et l'instant de référence ;
- les ancres déterministes verrouillées ;
- uniquement les identifiants opaques des lieux personnels déjà ancrés dans ce tour, avec un type générique et sans libellé enregistré, adresse ni coordonnées ;
- éventuellement le frame courant lorsqu'il s'agit d'une correction.

Sa sortie est exactement le même `IntentPatch` que l'adapter Foundation Models. L'iPhone applique le même validateur, le même résolveur de lieux et le même planificateur aux deux chemins.

### Ce qui doit disparaître du chemin nominal

- boucle agent multi-tour ;
- outils `search_places` et `plan_journeys` accessibles au modèle ;
- choix d'un candidat géographique par le modèle ;
- verdict `ready` fondé sur un handle de plan créé pendant la génération ;
- divergence entre préférences locales et calcul distant.

L'ancien agent peut rester temporairement disponible comme rollback global ou exécution d'observation, jamais comme troisième fallback silencieux.

## 5. La confiance doit être une politique d'acceptation mesurée

La prédiction sélective formalise le compromis risque/couverture : le système ne répond que sur une partie des entrées afin de contrôler le risque sur les réponses acceptées ([Geifman et El-Yaniv, 2019](https://proceedings.mlr.press/v97/geifman19a.html)). Cela soutient une politique d'abstention, mais pas l'usage naïf d'un nombre de confiance produit par le même modèle.

Via doit calculer l'acceptation par règles observables :

- preuve textuelle exacte ou alias enregistré ;
- correspondance géographique exacte ou candidat dominant avec marge mesurée ;
- absence de conflit entre ancres, modèle et état confirmé ;
- couverture de tous les slots critiques ;
- absence de fragment significatif ignoré ;
- contrainte du domaine validée.

Politique proposée :

| État | Action |
| --- | --- |
| Tous les champs critiques sont fondés et cohérents | Exécuter |
| Un champ critique manque | Demander ce champ |
| Deux candidats plausibles subsistent | Présenter les candidats |
| Modèle et ancre explicite divergent | Conserver l'ancre et demander confirmation si nécessaire |
| Les deux modèles échouent mais des faits restent fondés | Préserver le brouillon et compléter manuellement |
| Aucun fait utilisable | Expliquer la limite et proposer la recherche classique |
| Refus de sécurité | Ne pas transmettre à un autre modèle |

## 6. Évaluation : mesurer des capacités, pas compter des phrases

Apple demande de tester et itérer les prompts, fournit des outils d'évaluation structurée et rappelle que les versions du modèle embarqué évoluent avec l'OS ([Apple, Evaluating prompts](https://developer.apple.com/documentation/foundationmodels/evaluating-prompts-to-measure-performance-and-improve-model-responses)). OpenAI recommande également de construire les prompts contre un échantillon représentatif dans ses evals ([OpenAI, Working with evals](https://developers.openai.com/api/docs/guides/evals)).

Un corpus de neuf patrons répétés sur dix destinations ne mesure pas la robustesse linguistique. La suite Via doit être organisée par slices indépendantes :

1. **rôles de lieux** : ordre normal/inversé, impératif, ellipse ;
2. **lieux personnels** : Maison, Travail, alias, absence, collision ;
3. **géographie** : station/adresse, homonymes, erreurs courtes, ponctuation ;
4. **temps** : départ, arrivée, relatif, date passée, dernier service ;
5. **modes et contraintes** : requis, préféré, exclu, conflit, non supporté ;
6. **dialogue** : patch ciblé, pronom fondé, correction, fermeture de session ;
7. **erreurs** : refus, timeout, modèle indisponible, sortie invalide, réseau ;
8. **langues** : corpus français et anglais séparés ;
9. **sécurité** : injection, texte très long, contenu hors domaine ;
10. **métamorphique** : casse, accents, espaces, politesse, fautes et paraphrases.

Les seuils validés sont : 100 % sur les slices critiques et invariants « jamais inverser / jamais inventer / jamais ignorer », 99 % sur le corpus général. Les scores doivent être publiés par version iOS/modèle et par adapter, pas seulement sous forme d'une moyenne globale.

### Couches de preuve

- tests purs du moteur déterministe, toujours exécutables ;
- tests du module profond avec adapters modèle/search/journey en mémoire ;
- tests de contrat OpenAPI entre Swift et TypeScript ;
- evals réelles Foundation Models sur appareils et versions OS éligibles ;
- evals OpenAI sur le même corpus ;
- tests bout en bout avec fixtures de recherche incluant Auber, Rue Auber et Maison ;
- télémétrie de catégories sans phrase brute ;
- feedback de phrase uniquement après consentement pour chaque envoi.

Les travaux sur le semantic parsing à faible ressource montrent que l'augmentation de données structurées et filtrées peut améliorer le top-1 tout en respectant des contraintes de confidentialité ([Yang et al., 2022](https://aclanthology.org/2022.findings-acl.291/)). Via peut donc produire des paraphrases synthétiques, mais doit conserver un jeu d'évaluation humain séparé pour éviter de mesurer le générateur avec ses propres formulations.

## 7. Performance

Apple recommande de mesurer le chargement, l'inférence, le temps au premier token et les tokens avec l'instrument Foundation Models ; la taille des instructions et schémas contribue directement au coût ([Apple, Runtime performance](https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app)).

Le chemin cible optimise la latence par construction :

- bypass déterministe pour les phrases explicites ;
- préchauffage de la session à l'ouverture de la feuille IA ;
- une génération locale, pas une reformulation suivie d'une extraction ;
- instructions courtes et schéma minimal ;
- sampling déterministe ;
- résolution origine/destination parallèle ;
- un appel serveur structuré sans boucle à outils ;
- annulation de toute requête remplacée par un nouveau tour.

Les SLO validés restent : interprétation locale p95 ≤ 2,5 s, repli serveur p95 ≤ 5 s et premiers itinéraires p95 ≤ 8 s. Les temps doivent distinguer déterministe, Foundation Models, OpenAI, géocodage et planification.

## 8. Langues et versions de modèles

Apple demande de vérifier `supportsLocale(_:)` avant l'usage et explique que le même modèle est multilingue pour les langues prises en charge ([Apple, Languages and locales](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)). Via doit néanmoins maintenir des lexiques et corpus français/anglais distincts, car les ancres syntaxiques et les ambiguïtés ne sont pas les mêmes.

Le schéma de sortie reste unique. La locale sélectionne :

- le lexique déterministe ;
- les instructions concises ;
- le corpus d'évaluation ;
- l'adapter local si la locale est prise en charge ;
- sinon le repli serveur consenti.

Chaque changement de modèle Apple ou OpenAI impose la réexécution du corpus. Les alias mouvants sont acceptables en développement, mais une activation de production doit être liée à une configuration versionnée et à ses résultats d'eval.

## 9. Transparence et confidentialité

Les HIG demandent d'identifier clairement l'usage de l'IA, d'expliquer capacités et limites, de garder la personne en contrôle, de minimiser les données sensibles et d'obtenir une permission explicite pour l'amélioration ([Apple HIG, Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai)). Les HIG Settings recommandent peu d'options, un défaut adapté à la majorité et les réglages propres à une tâche au plus près de celle-ci ([Apple HIG, Settings](https://developer.apple.com/design/human-interface-guidelines/settings)).

Application au produit :

- fallback serveur actif après information claire pendant l'onboarding ;
- réglage général « Local uniquement » dans Moi ;
- état contextualisé dans la feuille lorsqu'un fallback va être utilisé ;
- `store: false`, identifiant pseudonymisé, aucun log de phrase ;
- identifiants opaques des seuls lieux personnels ancrés dans le tour, jamais leurs libellés enregistrés, adresses ou coordonnées ;
- aperçu et consentement à chaque feedback contenant une phrase ;
- corrections App Store et Réglages supprimant la promesse fausse « tout reste sur l'appareil ».

## 10. Faut-il entraîner un modèle Via ?

Pas maintenant. Les défaillances observées proviennent d'abord du contrat et du pipeline : lieux personnels non typés, aucune preuve de grounding, deux générations successives, repli divergent et corpus faible. Entraîner ou fine-tuner un modèle sur cette interface fragile figerait ces défauts.

Ordre recommandé :

1. construire le frame, les patches, le validateur et les adapters ;
2. atteindre les gates avec Foundation Models et OpenAI contraints ;
3. collecter uniquement des feedbacks consentis et labellisés ;
4. analyser les slices qui plafonnent ;
5. envisager un adapter ou fine-tuning seulement si les evals montrent un gain net de qualité à coût de maintenance acceptable.

Un futur modèle spécialisé ne remplacerait toujours pas le validateur, le résolveur ni la politique d'abstention.

## 11. Architecture recommandée

```text
NaturalJourneyTurn
  phrase + locale + now + saved aliases + optional current state
                         │
                         ▼
Deterministic grounding
  explicit roles + personal places + time/modes + evidence
                         │
             complete and coherent? ───── yes ──┐
                         │ no                    │
                         ▼                       │
Local structured interpreter                    │
                         │ technical/invalid    │
                         ▼                       │
Consented server structured interpreter         │
                         │                       │
                         └──────────┬────────────┘
                                    ▼
Merge + domain validation + selective acceptance
                 │                 │                 │
               accept          clarify           reject
                 │                 │                 │
                 ▼                 ▼                 ▼
Typed dialogue state       targeted patch UI    classic search
                 │
                 ▼
Shared place resolver → shared journey planner → verified results
```

### Interfaces à tester

1. **Compréhension** — `interpret(turn, state) -> transition` : interface principale et profonde.
2. **Exécution** — `submit(request) -> NaturalJourneyResult` : trajet bout en bout avec adapters de lieux et de planification.
3. **Contrat distant** — phrase + ancres + alias opaques vers le même patch typé, sans outils de trajet.
4. **Présentation** — soumission/correction vers un état observable de `SearchViewModel`.

Les adapters externes justifiés sont Foundation Models, OpenAI, recherche de lieux, planification et horloge. Le parseur déterministe, la fusion, le validateur et le dialogue state tracker restent des détails internes du module de compréhension.

## Décision finale

La recherche ne révèle pas une technique magique qui rendrait un LLM infaillible. Elle renforce au contraire une architecture où l'intelligence vient de la combinaison suivante : schéma de dialogue explicite, modèle contraint, grounding déterministe, connaissances Via, abstention mesurée, mémoire par patches et evals continues.

Pour le cas signalé, la garantie ne doit pas être « le prompt comprend probablement mieux ». Elle doit être structurelle : `chez moi` est un identifiant personnel typé, `depuis Auber` est une origine verrouillée, et aucun adapter modèle n'a le pouvoir de les inverser.
