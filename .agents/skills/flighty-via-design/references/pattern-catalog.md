# Flighty Via — catalogue des patterns

Ce catalogue synthétise les motifs qui reviennent dans l’atlas. Il sert à choisir une abstraction et à éviter de redessiner un contrôle Apple ou de créer une variante visuelle isolée.

## 1. Shell et navigation

| Pattern | Règle visuelle | Contrat d’interaction | Réutilisation Via | Apple natif |
| --- | --- | --- | --- | --- |
| Carte-contexte | La carte occupe le fond et reste lisible sous les surfaces flottantes. | Les annotations sont sélectionnées par MapKit; les contrôles flottants ont des labels VoiceOver. | `NetworkMapView`, `MapShellBackground` | `Map`, `Map(selection:)`, `MapUserLocationButton`, `MapCompass` |
| Sheet principale | Surface blanche/opaque, grands coins supérieurs, marge horizontale constante, contenu sous la safe area. | Drag/detents et interaction carte sont fournis par le système existant. | `adaptiveSheetPresentation` | `sheet`, `presentationDetents`, `presentationBackgroundInteraction` |
| Navigation de premier niveau | Quatre destinations lisibles, Recherche distincte et à droite. | Sélection persistante; fermeture de Recherche restaure l’onglet précédent. | `AppTab`, `AppShellView` | `TabView(selection:)`, `Tab(role: .search)` |
| Parcours secondaire | Titre de contexte, retour système, hiérarchie claire. | Les actions destructives sortent en confirmation. | `NavigationStack` | `NavigationStack`, `navigationDestination`, `confirmationDialog` |

## 2. Surfaces et typographie

| Pattern | Description | État à prévoir |
| --- | --- | --- |
| Hero title | Titre noir large, souvent en 32–40 pt, suivi d’une explication courte gris secondaire. | Longs textes avec Dynamic Type et wrapping naturel. |
| Flighty card | Fond secondaire très léger, rayon généreux, padding 16–20, pas de contour dur par défaut. | Normal, sélection, disabled, warning, disrupted. |
| Sélection explicite | Contour bleu ou accent autour d’une carte entière; l’épaisseur augmente légèrement mais la typographie ne bouge pas. | `isSelected` annoncé par le texte/VoiceOver, pas seulement la couleur. |
| Groupe de réglages | `List`/`Section` natif pour la structure; accent Flighty uniquement sur les badges et états. | Loading, local, syncing, synced, failed, pendingOffline. |
| Hairline | Séparateur fin et discret entre rows homogènes. | Éviter les séparateurs qui coupent une carte indépendante. |

## 3. Recherche et saisie

| Pattern | Description | Composant | Natif |
| --- | --- | --- | --- |
| Recherche par étapes | Origine puis destination; la valeur validée devient un token compact, le champ actif reste extensible. | `SearchTokenField` | `TextField`, `FocusState`, keyboard toolbar |
| Capture R1 | `[SFO]` dans un pill gris à gauche, `[lax|]` dans une surface grise large, curseur bleu après `lax`, clear circulaire gris à droite. | `SearchTokenField` avec `Token` et `ActiveQuery` | `TextField` + `Button` clear, jamais une fausse barre image |
| Résultat | Icône de type à gauche, titre noir, code/contexte secondaire, action trailing. | `SearchResultRow` | `Button`, `Label`, `contentShape` seulement pour agrandir une vraie Button |
| Langage naturel | Une phrase libre peut être soumise depuis l’état planner et reçoit loading, clarification, réponse ou indisponibilité. | `SearchTokenField`, `NaturalJourneySuggestionRow`, `NaturalJourneyAnswerCard` | `TextField`, `.onSubmit` |
| Recents | Liste secondaire, suppression contextualisée, pas de nouvelle route pour chaque item. | `RecentSearchRow` | `swipeActions`, `contextMenu` pour actions secondaires |

## 4. Transit

| Pattern | Description | Composant |
| --- | --- | --- |
| Station row | Nom et code lisibles, mode en glyph/badge, état de service secondaire, trailing chevron. | `StationRow` |
| Départ | Direction/destination principale, minutes en chiffres tabulaires, ligne colorée, retard en clair. | `DepartureDirectionRow`, `DepartureLineRow` |
| Badge ligne | Petit badge à couleur de réseau, texte court à contraste élevé, forme indépendante du statut. | `LineBadgeView`, `RouteLineBadgeView` |
| Carte Lignes | Badge, nom/destination, résumé d’incident, gravité visible et date de mise à jour. | `LineStatusCard` |
| Perturbation | Rouge/orange accompagné d’un symbole et de mots (“Perturbée”, “Suspendue”, “Attention”). | `LineCondition` + `StatusBadgeView` |
| Graphique | Encadré lisible, axe simple, couleur d’accent réservée aux données; explication hors graphique. | composant de feature dédié | `Chart` si disponible, sinon rendu statique accessible |

## 5. États et feedback

| État | Composition | Action |
| --- | --- | --- |
| Empty | Icône/illustration discrète, titre court, explication, CTA unique. | Le CTA mène à la prochaine action (Stations → Recherche, Friends → invitation). |
| Loading | Même géométrie que le contenu attendu avec skeletons neutres; pas de flash. | Annulation/retry seulement si le chargement est contrôlable. |
| Error | Titre explicite, cause en langage humain, retry local au contenu. | `Button` “Réessayer”; garder les données précédentes si elles restent valides. |
| Normal | Accent vert/bleu réservé aux données utiles, surface calme. | Action principale lisible. |
| Warning | Orange/ambre + résumé + impact, jamais couleur seule. | Ouvrir le détail ou corriger. |
| Disrupted | Rouge avec texte et affected stops; carte mise en avant dans Lignes. | Détail ligne/station, éventuellement notifications. |
| Suspended | État plus fort que disrupted, texte “Suspendue” et alternative si connue. | Orienter vers une alternative; ne pas promettre un départ. |

## 6. Pro / beam / social

| Pattern | Description | Règle |
| --- | --- | --- |
| PRO benefit card | Contour/tint lavande, pill “PRO”, texte de bénéfice sur deux lignes et chevron. | Le badge ne remplace pas la description; la carte reste accessible. |
| Beam CTA | Halo/beam coloré autour d’un CTA IA ou d’une action principale. | Reprendre `BorderBeamEffect`; `reduceMotion` désactive l’animation, pas l’action. |
| Friend alert choice | Quatre grandes cartes de préférence, une seule entourée en bleu; icône colorée + titre + description. | `FriendAlertPreferencesView`, `FriendAlertOptionCard`, `Picker`/état sélectionné selon le contexte; carte complète sélectionnable. |
| Share | Prévisualisation de contenu puis système de partage. | `ShareLink` ou `UIActivityViewController` via wrapper seulement si le payload l’exige. |

## 7. Architecture des composants

- Le modèle de feature possède les états et l’intention; le composant visuel reçoit des valeurs et des closures.
- Un écran de tab ne doit pas connaître le détail du réseau HTTP. Injecter `LineStatusRepository` ou le view model existant.
- Un composant de carte ne présente pas une sheet par effet de bord; l’écran parent décide de la route.
- Un `Menu` filtre une collection et garde la valeur sélectionnée visible. Un `contextMenu` reste réservé aux actions secondaires et ne doit pas contenir l’unique chemin vers une fonction.
- Les surfaces Flighty peuvent être custom; le focus, le clavier, la navigation, les confirmations et les menus restent système.

## 8. Spacing et tokens de départ

Ces valeurs sont des points de départ cohérents avec les captures, non des contraintes absolues : marge écran 16–20, groupe 24–32, gap row 12–16, padding carte 16–20, petit rayon 10–14, carte 18–24, sheet 28–36, bouton principal hauteur 50–56. Les valeurs adaptent le Dynamic Type et la largeur disponible plutôt que de forcer une taille fixe.
