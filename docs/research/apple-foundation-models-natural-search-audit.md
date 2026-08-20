# Audit Apple Foundation Models — recherche naturelle de trajets

Date de vérification : 20 août 2026.

## Objet et méthode

Cette note confronte l’implémentation de `apps/via/via/Features/NaturalJourneys`, son branchement dans `ApplicationEntry` et ses tests aux sources primaires Apple actuelles. Elle distingue les prérequis réellement manquants des améliorations de qualité. Aucun code applicatif n’a été modifié pendant cet audit.

Le diagnostic exact de l’échec observé sur iPhone n’est pas récupérable avec la télémétrie actuelle : le parseur transforme plusieurs erreurs Apple et plusieurs rejets propres à Via en une même erreur `invalidResponse`, puis ne conserve que cette catégorie. Il est donc impossible de savoir a posteriori si le modèle a produit une erreur de décodage, si un guide a été refusé ou si `GeneratedRouteIntent.domain()` a rejeté une sortie pourtant structurellement valide.

## Verdict

Le framework est correctement importé et branché, la cible iOS 26 est adaptée, `SystemLanguageModel.default` est le bon modèle et **aucun entitlement Foundation Models n’est requis pour utiliser le modèle local standard**. Les entitlements Apple documentés concernent des fonctions séparées, comme les adaptateurs personnalisés ou Private Cloud Compute. Via n’utilise ni l’un ni l’autre. ([Apple — Foundation Models](https://developer.apple.com/documentation/foundationmodels/), [Apple — entitlement des adaptateurs](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.developer.foundation-model-adapter))

En revanche, l’implémentation n’est pas encore suffisamment robuste pour être considérée fonctionnelle sur modèle réel. Trois défauts prioritaires peuvent expliquer une succession d’échecs sur des phrases ordinaires :

1. le schéma `@Generable` autorise de nombreux états que le validateur Via refuse ensuite ;
2. le modèle doit calculer lui-même les dates relatives et produire un ISO 8601 exact, alors qu’Apple demande de réduire le raisonnement confié au modèle embarqué ;
3. le test de corpus qui devait découvrir ces problèmes ignore inconditionnellement le simulateur et n’a donc fourni aucune preuve de fonctionnement réel.

## États détectables et actions utilisateur justifiées

Sur iOS 26, `SystemLanguageModel.Availability.UnavailableReason` ne publie que trois raisons : `appleIntelligenceNotEnabled`, `deviceNotEligible` et `modelNotReady`. Il ne publie ni progression de téléchargement, ni état `downloadInProgress`, ni cause « stockage insuffisant », ni raison propre à une région ou à une langue. Les conditions de langue doivent être testées séparément avec `supportsLocale(_:)`, puis gérées à l’exécution avec `unsupportedLanguageOrLocale`. ([Apple — `UnavailableReason`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason), [Apple — langues et locales](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models))

| Condition observable | Signal public | Ce qu’Apple permet d’affirmer | Action Via justifiée |
| --- | --- | --- | --- |
| Prêt et français pris en charge | `.available` et `supportsLocale(fr_FR) == true` | Le modèle est prêt à recevoir des requêtes dans cette locale. | Afficher et activer la recherche naturelle. |
| Apple Intelligence désactivée | `.unavailable(.appleIntelligenceNotEnabled)` | Apple Intelligence n’est pas activée sur le système. | Expliquer l’état et inviter à l’activer dans **Réglages > Apple Intelligence et Siri** ; garder la recherche classique. Le tutoriel Apple emploie explicitement « Please enable it in Settings ». ([Apple — tutoriel de disponibilité](https://developer.apple.com/tutorials/develop-in-swift/generate-structured-content), [Apple Assistance — activation](https://support.apple.com/fr-fr/121115)) |
| Modèle non prêt | `.unavailable(.modelNotReady)` | Les modèles nécessaires ne sont pas disponibles sur l’appareil. Ils se téléchargent automatiquement selon, entre autres, le réseau, la batterie et la charge système ; Apple précise cependant que cet état peut aussi avoir « other system reasons ». | Dire « Le modèle n’est pas encore prêt » et proposer **Réessayer plus tard**. Il est légitime d’indiquer que Wi‑Fi et alimentation accélèrent un téléchargement éventuel, mais pas d’affirmer qu’un téléchargement est en cours ni d’afficher une progression inexistante. ([Apple — `modelNotReady`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason/modelnotready), [Apple — vérification de disponibilité](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models), [Apple Assistance — téléchargement](https://support.apple.com/fr-fr/121115)) |
| Appareil incompatible | `.unavailable(.deviceNotEligible)` | L’appareil ne prend pas en charge Apple Intelligence. | Masquer ou désactiver cette expérience et laisser le formulaire classique. Il n’existe pas d’action Réglages capable de rendre l’appareil éligible. ([Apple — tutoriel de disponibilité](https://developer.apple.com/tutorials/develop-in-swift/generate-structured-content)) |
| Français ou locale non pris en charge | `supportsLocale(fr_FR) == false`, ou `GenerationError.unsupportedLanguageOrLocale` sur iOS 26 | La locale ou une langue de la requête n’est pas prise en charge par le modèle. Ce n’est pas un cas de `UnavailableReason`. | Expliquer que la langue n’est pas prise en charge, désactiver la fonction Foundation Models et proposer l’expérience classique, conformément aux trois actions demandées par Apple. ([Apple — langues et locales](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models), [Apple — erreur iOS 26](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror/unsupportedlanguageorlocale(_:))) |
| Raison d’indisponibilité future ou inconnue | `.unavailable(let other)` / `@unknown default` | Aucune cause précise ne peut être communiquée. | Message neutre, réessai et recherche classique ; ne pas inventer de remède. ([Apple — `SystemLanguageModel`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)) |
| Assets perdus pendant une session | `GenerationError.assetsUnavailable` sur iOS 26 ; `SystemLanguageModel.Error.assetsUnavailable` à partir du SDK iOS 27 | Les assets requis ne sont plus disponibles. Apple cite notamment leur suppression ou la désactivation d’Apple Intelligence pendant l’exécution. | Relire immédiatement `model.availability`, puis appliquer la ligne correspondante ci-dessus. Cette erreur, seule, ne prouve pas un téléchargement. ([Apple — `assetsUnavailable`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/error/assetsunavailable(_:))) |

La page Assistance Apple ajoute des prérequis système généraux : dernière version du logiciel, 7 Go de stockage, et langues de l’appareil et de Siri identiques et prises en charge. Après une mise à jour ou un changement de langue de Siri, les modèles peuvent prendre du temps à se télécharger ; Apple conseille Wi‑Fi et alimentation pour accélérer ce processus. Ces informations peuvent enrichir une aide secondaire, mais elles ne transforment pas `.modelNotReady` en diagnostic certain de téléchargement ou de manque de stockage. Aucune source Apple publique consultée ne recommande de redémarrer l’appareil pour ces états : Via ne doit donc pas présenter le redémarrage comme correctif officiel. ([Apple Assistance — configuration et téléchargement](https://support.apple.com/fr-fr/121115))

### `com.apple.SensitiveContentAnalysisML error 15` n’est pas un état public

La chaîne `com.apple.SensitiveContentAnalysisML error 15` n’apparaît dans aucun type d’erreur public Foundation Models documenté par Apple. Dans le seul fil Apple Developer Forums trouvé avec cette chaîne exacte, elle provient du rapport d’un développeur ; l’ingénieur Apple ne lui attribue aucune signification et demande seulement de déposer un rapport via Feedback Assistant. Le second message Apple demande si une bêta ultérieure a résolu le problème. ([Apple Developer Forums — « Sensitive Content Error When Using Foundation Models »](https://developer.apple.com/forums/thread/836285))

Verdict : il n’est **pas légitime** de mapper le code non documenté `15` à « modèle en téléchargement », à « contenu sensible » ou à toute autre cause utilisateur. Via doit le traiter comme un échec modèle inconnu, relire `SystemLanguageModel.default.availability`, n’afficher « modèle non prêt » que si cette lecture retourne `.modelNotReady`, et sinon proposer un réessai et la recherche classique. En développement, le domaine et le code peuvent être conservés sans la phrase utilisateur afin de joindre un diagnostic à Feedback Assistant. Aucun conseil de redémarrage n’est étayé par Apple pour cette erreur.

## Constats prioritaires

### P0 — Le schéma guidé n’exprime pas les invariants que Via exige ensuite

Dans `GeneratedRouteIntent.swift`, la génération guidée garantit la **forme Swift**, mais plusieurs contraintes métier ne figurent pas dans le schéma :

- `origin.kind == place` exige ensuite un `origin.query` non vide ;
- `alternateRequestedAt` et `alternateDatetimeRepresents` doivent ensuite être tous deux présents ou tous deux absents ;
- la valeur alternative `ambiguous` est générable, mais refusée par `domain()` ;
- `requestedAt` et sa valeur alternative doivent être des chaînes ISO 8601 que le parseur Foundation de Via accepte exactement ;
- quatre tableaux décrits en français comme contenant « au plus trois » éléments n’ont aucun `maximumCount(3)` ;
- les contraintes non prises en charge dépassant 160 caractères ou vides sont générables, puis rejetées.

Apple garantit la correction structurelle d’un type `@Generable`, pas les relations métier ajoutées après la génération. Apple recommande précisément d’encoder les bornes de tableaux avec `@Guide(..., .maximumCount(...))` et de simplifier les types générables. ([Apple — Generating Swift data structures with guided generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation), [Apple — `maximumCount(_:)`](https://developer.apple.com/documentation/foundationmodels/generationguide/maximumcount(_:)), [Apple — Managing the context window](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window))

Conséquence : une réponse peut être parfaitement valide pour Foundation Models, puis devenir `NaturalIntentParsingError.invalidResponse` aux lignes 87, 94, 103, 114, 121, 134, 139 ou 146 de `GeneratedRouteIntent.swift`. L’interface affichait alors le même message que pour une vraie erreur de génération.

Correction recommandée : rendre les états invalides impossibles dans le type généré. Par exemple, représenter l’origine et la contrainte horaire alternative par des types imbriqués cohérents plutôt que par des champs indépendants, appliquer `maximumCount(3)` aux tableaux, puis réserver la validation après génération aux contrôles de sécurité réellement impossibles à exprimer dans le schéma.

### P0 — Via demande au modèle du calcul calendaire et un formatage exact

`FoundationModelsIntentParser.instructions(now:)` demande au modèle de :

- résoudre « aujourd’hui », « demain », les jours de semaine et les durées relatives ;
- calculer un instant à partir de `now` ;
- appliquer le fuseau Europe/Paris ;
- produire une chaîne ISO 8601 exacte ;
- inventer un midi technique lorsqu’une date n’a pas d’heure.

Apple décrit le modèle embarqué comme adapté à l’extraction et à la classification, mais déconseille le calcul et le raisonnement logique. Apple recommande de réduire la réflexion demandée et de découper les tâches complexes. ([Apple — Generating content and performing tasks with Foundation Models](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models), [Apple — Explore prompt design & safety, WWDC25](https://developer.apple.com/videos/play/wwdc2025/248/), [Apple — Prompting an on-device foundation model](https://developer.apple.com/documentation/foundationmodels/prompting-an-on-device-foundation-model))

Ce choix est particulièrement fragile parce que tout trajet sans date ni heure demande quand même au modèle de recopier l’instant actuel dans `requestedAt`. Une simple variation de format transforme donc une demande triviale en `invalidResponse`.

Correction recommandée : faire seulement extraire des composants sémantiques — date absente, aujourd’hui, demain, prochain jour de semaine, date explicite, heure, partie de journée ou durée relative — puis calculer le `Date` avec `Calendar` configuré sur `Europe/Paris`. Le modèle ne doit pas faire de calcul calendaire ni sérialiser une date de transport.

### P0 — La porte qualité de 100 phrases n’est pas réellement exécutée

`NaturalJourneyIntentEvalTests.testAnnotatedFrenchJourneyCorpus()` ignore tous les simulateurs avec `#if targetEnvironment(simulator)`, avant même d’interroger `parser.availability`. Cette hypothèse est contredite par la démonstration Apple : le code-along WWDC25 compare explicitement la performance d’un simulateur sur Mac M4 à celle d’un ancien iPhone. Le simulateur peut donc exécuter le modèle lorsque son hôte et ses ressources sont éligibles. ([Apple — Code-along Foundation Models, WWDC25](https://developer.apple.com/videos/play/wwdc2025/259/))

Le test ne doit pas supposer l’indisponibilité du simulateur. Il doit demander `SystemLanguageModel.default.availability` et ignorer uniquement l’environnement réellement indisponible. Apple recommande également Xcode `#Playground` pour itérer immédiatement sur les prompts et le schéma. ([Apple — Meet the Foundation Models framework, WWDC25](https://developer.apple.com/videos/play/wwdc2025/286/))

La présence de 100 cas dans un tableau ne constitue donc pas une preuve que les 100 formulations passent. À ce stade, aucune exécution modèle enregistrée dans le dépôt ne démontre même qu’une phrase produit un `GeneratedRouteIntent` accepté.

### P1 — La consigne de locale recommandée par Apple manque

Via vérifie correctement `model.supportsLocale(Locale(identifier: "fr_FR"))`. Le français est bien une langue Apple Intelligence prise en charge, et `supportsLocale(_:)` est la méthode recommandée, car elle tient compte des équivalences et fallbacks de locale. ([Apple — Supporting languages and locales](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models), [Apple — `supportsLocale(_:)`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/supportslocale(_:)), [Apple Assistance — langues Apple Intelligence](https://support.apple.com/fr-fr/121115))

Mais Apple demande, pour une locale autre que l’anglais américain, de commencer les instructions par la formule anglaise exacte issue de l’entraînement :

```text
The person's locale is fr_FR.
```

Apple conseille ensuite de préciser explicitement la langue de sortie. Via indique seulement en français que l’entrée est une « phrase française ». Il faut ajouter une contrainte explicite telle que `You MUST interpret and preserve place names in French.` ou son équivalent testé, puis mesurer son effet sur le corpus. ([Apple — Supporting languages and locales](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models))

Ce manque n’explique pas à lui seul un échec systématique, mais il réduit la fiabilité de la génération multilingue, notamment parce que les noms de propriétés et de cas du schéma sont en anglais alors que les descriptions, instructions et saisies sont en français.

### P1 — Les entrées ouvertes ne sont pas enveloppées dans un prompt applicatif

La phrase de la personne est passée directement à `session.respond(to:)`. Les instructions disent bien qu’elle est non fiable, ce qui est positif, mais Apple recommande également d’envelopper l’entrée libre dans un prompt appartenant à l’app afin de mieux orienter le modèle et de renforcer la séparation entre commande et donnée. ([Apple — `Prompt`](https://developer.apple.com/documentation/foundationmodels/prompt), [Apple — Improving the safety of generative model output](https://developer.apple.com/documentation/FoundationModels/improving-the-safety-of-generative-model-output))

Correction recommandée : construire un `Prompt` court du type « Extrais uniquement l’intention de trajet contenue dans la saisie suivante : … », sans déplacer la saisie utilisateur dans les `Instructions`. Apple déconseille explicitement de placer une entrée non fiable dans les instructions.

### P1 — Le mode d’échantillonnage n’est pas fixé pour une tâche déterministe

Via laisse `GenerationOptions` à sa valeur par défaut. Pour cette extraction, la variété n’apporte aucune valeur. Apple documente `.greedy` comme choisissant toujours le token le plus probable et comme produisant le même résultat pour une même entrée ; son sample officiel l’utilise pour obtenir des résultats cohérents. ([Apple — `greedy`](https://developer.apple.com/documentation/foundationmodels/generationoptions/samplingmode-swift.struct/greedy), [Apple — sample Foundation Models](https://developer.apple.com/documentation/foundationmodels/adding-intelligent-app-features-with-generative-models))

Correction recommandée : tester `GenerationOptions(samplingMode: .greedy)` sur le corpus, puis le conserver s’il améliore la précision et la stabilité. Il ne faut pas lui attribuer une garantie métier : un résultat déterministe peut rester faux.

### P1 — Le détail de l’erreur Apple nécessaire au diagnostic est perdu

Sur l’API iOS 26, `LanguageModelSession.GenerationError` distingue notamment :

- `assetsUnavailable` ;
- `decodingFailure` ;
- `exceededContextWindowSize` ;
- `rateLimited` ;
- `guardrailViolation` et `refusal` ;
- `concurrentRequests` ;
- `unsupportedGuide` ;
- `unsupportedLanguageOrLocale`.

Le mapping Via des catégories est globalement correct pour iOS 26. Toutefois, `unsupportedGuide` et `decodingFailure` deviennent tous deux `invalidResponse`, tout comme tous les rejets de `domain()`. La couche supérieure journalise ensuite seulement `invalidResponse`. Apple fournit `GenerationError.Context.debugDescription` précisément pour aider au diagnostic pendant le développement. ([Apple — `LanguageModelSession.GenerationError`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror), [Apple — `GenerationError.Context.debugDescription`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror/context/debugdescription))

Correction recommandée : séparer au minimum les étapes `frameworkGeneration` et `domainValidation`, enregistrer en DEBUG la catégorie Apple et un code précis de validation Via, sans enregistrer la phrase, le lieu ni le transcript. Le `debugDescription` Apple est destiné au diagnostic, pas à l’interface ; il faut le contrôler avant toute télémétrie de production.

### P1 — L’API d’erreurs doit être préparée pour Xcode 27

Le code actuel est cohérent avec le SDK iOS 26 : `LanguageModelSession.GenerationError` est disponible d’iOS 26 à iOS 27. Apple l’a toutefois déprécié et a séparé les erreurs, à partir du SDK iOS 27, entre `LanguageModelError`, `SystemLanguageModel.Error` et `LanguageModelSession.Error`. Apple précise qu’une app compilée avec Xcode 26 continue d’attraper l’ancien type, mais qu’une recompilation avec Xcode 27 exige les nouveaux types. ([Apple — Foundation Models updates](https://developer.apple.com/documentation/Updates/FoundationModels), [Apple — `LanguageModelError`](https://developer.apple.com/documentation/foundationmodels/languagemodelerror), [Apple — `SystemLanguageModel.Error`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/error), [Apple — `LanguageModelSession.Error`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/error))

Ce n’est pas la cause d’un échec dans une build Xcode 26, mais l’actuel `catch` générique transformera les nouveaux cas en `modelFailed` après migration si aucun branchement conditionnel n’est ajouté.

### P2 — Le budget de contexte n’est ni mesuré ni borné

Le modèle iOS 26 dispose d’une fenêtre de 4 096 tokens. Instructions, prompt, schéma `@Generable` et réponse partagent ce budget. Via recrée une session à chaque requête, ce qui évite correctement l’accumulation d’un historique, mais n’impose aucune taille maximale à la phrase et ne mesure pas le coût du schéma. ([Apple — Managing the context window](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window), [Apple — TN3193](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window))

Pour les phrases normales de Via, le dépassement ne devrait pas être systématique. Il reste nécessaire de borner raisonnablement la saisie, de mesurer `tokenCount(for:)` sur les versions qui le permettent et de profiler avec l’instrument Foundation Models.

### P2 — Le corpus ne couvre pas la matrice des modèles système

Apple a modifié le modèle embarqué avec iOS 26.4 et demande explicitement de retester les prompts lors des mises à jour du modèle. Le corpus Via s’exécute sur un unique environnement disponible et ne conserve pas de résultat par version d’OS/modèle. ([Apple — Foundation Models updates](https://developer.apple.com/documentation/Updates/FoundationModels))

La porte de sortie doit au minimum être mesurée sur iOS 26.0–26.3 et iOS 26.4, puis sur toute nouvelle version prise en charge. Apple rappelle que la sortie d’un modèle peut varier même avec une même entrée ; une évaluation systématique est nécessaire. ([Apple — Evaluating prompts](https://developer.apple.com/documentation/foundationmodels/evaluating-prompts-to-measure-performance-and-improve-model-responses))

## Points correctement implémentés

- `SystemLanguageModel.default.availability` est consulté avant l’usage et les trois raisons iOS 26 (`deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady`) sont distinguées. Cette structure correspond au sample Apple. ([Apple — `UnavailableReason`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason), [Apple — sample Foundation Models](https://developer.apple.com/documentation/foundationmodels/adding-intelligent-app-features-with-generative-models))
- `supportsLocale(fr_FR)` est utilisé plutôt qu’une liste codée en dur.
- `LanguageModelSession` est créée après le contrôle de disponibilité et une nouvelle session est utilisée par interprétation. Il n’y a donc ni transcript partagé ni historique implicite entre deux demandes.
- Une seule réponse est demandée par session ; Via ne viole pas la règle Apple interdisant deux réponses concurrentes sur une même session. ([Apple — `LanguageModelSession`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession))
- `respond(to:generating:)` inclut le schéma dans le prompt par défaut ; Via n’a pas oublié `includeSchemaInPrompt: true`. Apple recommande de conserver cette valeur par défaut sauf si le modèle connaît déjà exhaustivement le format. ([Apple — réponse générable](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/respond(to:generating:options:contextoptions:metadata:)))
- Les tableaux utilisent des types `Array` et les catégories des enums `@Generable`, tous pris en charge par la génération guidée.
- `ApplicationEntry` injecte bien le parseur réel dans `OnDeviceNaturalJourneyService`. Après interprétation, seuls les lieux extraits et les critères structurés sont envoyés aux services Via ; la phrase originale n’est pas transmise au serveur dans ce chemin.
- La cible principale est iOS 26, Swift 6 strict, avec une équipe de développement configurée. Il n’existe pas de clé Info.plist, permission utilisateur, API key ou entitlement à ajouter pour le modèle local standard.

## Ordre de correction recommandé

1. **Rendre l’échec observable en développement** : distinguer erreur Apple et rejet `domain()`, conserver une catégorie sûre et précise, puis reproduire une phrase sur l’iPhone concerné.
2. **Réduire le schéma** : extraire des composants de date au lieu d’un ISO calculé, regrouper les champs dépendants et ajouter les guides `maximumCount(3)`.
3. **Aligner le prompt Apple** : formule exacte de locale, langue française explicite, prompt applicatif enveloppant la saisie, moins de règles dans une seule tâche.
4. **Évaluer `.greedy`** et garder le réglage seulement si le corpus confirme le gain.
5. **Réactiver les essais simulateur** par détection de disponibilité, puis exécuter les 100 cas sur appareil et simulateur éligibles.
6. **Bloquer l’activation générale** tant que le seuil de 95 % et les clarifications critiques ne passent pas réellement sur les versions iOS ciblées.
7. **Ajouter la compatibilité Xcode 27** avant toute migration de toolchain, sans abandonner la cible de déploiement iOS 26.

## Protocole de validation minimal

- [ ] Dans Xcode `#Playground`, une phrase triviale produit et affiche le `GeneratedRouteIntent` brut.
- [ ] Sur l’iPhone ayant reproduit le problème, la catégorie exacte est connue : erreur Apple ou validation Via.
- [ ] Les trois suggestions de l’interface passent dix fois de suite sans erreur technique.
- [ ] Le corpus de 100 formulations atteint au moins 95 % sur les demandes non ambiguës.
- [ ] 100 % des destinations, origines, dates ou heures critiques manquantes aboutissent à une clarification.
- [ ] Aucun calcul de date n’est confié au modèle ; les changements heure d’été/hiver Europe/Paris sont testés dans le code déterministe.
- [ ] Les matrices iOS 26.0–26.3 et iOS 26.4 sont mesurées séparément.
- [ ] Les états Apple Intelligence désactivée, modèle non prêt, appareil non éligible et français non pris en charge sont testés.
- [ ] Le simulateur n’est ignoré que lorsque `availability` indique réellement une indisponibilité.
- [ ] Aucun test ni journal de production ne conserve la phrase, les lieux ou le transcript.

## Sources primaires Apple

- [Foundation Models](https://developer.apple.com/documentation/foundationmodels/)
- [`SystemLanguageModel.Availability.UnavailableReason`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason)
- [`SystemLanguageModel.Availability.UnavailableReason.modelNotReady`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason/modelnotready)
- [`SystemLanguageModel.Error.assetsUnavailable(_:)`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/error/assetsunavailable(_:))
- [Generating content and performing tasks with Foundation Models](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models)
- [Supporting languages and locales with Foundation Models](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)
- [Generating Swift data structures with guided generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation)
- [Prompting an on-device foundation model](https://developer.apple.com/documentation/foundationmodels/prompting-an-on-device-foundation-model)
- [Managing the context window](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window)
- [Foundation Models updates](https://developer.apple.com/documentation/Updates/FoundationModels)
- [Evaluating prompts to measure performance and improve model responses](https://developer.apple.com/documentation/foundationmodels/evaluating-prompts-to-measure-performance-and-improve-model-responses)
- [Code-along: Bring on-device AI to your app using the Foundation Models framework — WWDC25](https://developer.apple.com/videos/play/wwdc2025/259/)
- [Meet the Foundation Models framework — WWDC25](https://developer.apple.com/videos/play/wwdc2025/286/)
- [Explore prompt design & safety for on-device foundation models — WWDC25](https://developer.apple.com/videos/play/wwdc2025/248/)
- [Generate structured content — tutoriel de disponibilité](https://developer.apple.com/tutorials/develop-in-swift/generate-structured-content)
- [Comment obtenir Apple Intelligence — Assistance Apple](https://support.apple.com/fr-fr/121115)
- [Apple Developer Forums — Sensitive Content Error When Using Foundation Models](https://developer.apple.com/forums/thread/836285)
