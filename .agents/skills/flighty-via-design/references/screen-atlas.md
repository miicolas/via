# Flighty Via — atlas descriptif des captures

## Méthode de lecture

Les captures de référence proviennent de `/Users/nicolasbecharat/Downloads/Flighty ios Aug 2026/`, numérotées `0` à `236`, en portrait 1180 × 2676. Les images sont une référence visuelle; ce fichier en conserve la description utilisable sans charger les bitmaps. Les zones système (status bar, home indicator, clavier) sont considérées comme appartenant à iOS et non à une surface applicative.

Chaque fiche distingue : but et état, fond/surface et géométrie, hiérarchie de contenu, contrôles et transitions, puis réutilisation Via et API Apple. Les mots en capitales sont les labels visibles ou les états de service. Les captures `R1` et `R2` sont les deux images fournies par l’utilisateur.

## 0–2 — lancement et shell principal

### Capture 000 — lancement Flighty

- **But / état :** écran de lancement, aucune donnée métier; le produit est identifiable avant le shell.
- **Fond / composition :** surface sombre presque noire, logotype Flighty et petit crédit centré; pas de sheet ni de contrôle interactif visible.
- **Interaction / transition :** état transitoire vers la carte et les tabs; il ne doit pas recevoir d’action utilisateur.
- **Via / Apple :** `LaunchScreen` ou scène système, jamais un faux écran de navigation; utiliser une surface de marque minimale.

### Capture 001 — My Flights avec invitation Pro

- **But / état :** shell principal après lancement; la liste des vols est vide et un bénéfice Pro propose d’ajouter le prochain vol.
- **Fond / composition :** carte géographique claire en plein écran avec régions et villes; surface de contenu flottante basse, coins généreux et tab bar sombre/translucide en bas. Le titre “My Flights” est centré au-dessus de la liste.
- **Contenu / actions :** carte Pro “Welcome! Get a Free Upgrade”, CTA d’ajout, tabs `My Flights`, `Friends`, `Passport`; les contrôles de carte restent flottants.
- **Via / Apple :** `Map` + `TabView`; pour Via, `Stations` est l’équivalent empty-first, avec `EmptyStateView` et CTA vers `Recherche`.

### Capture 002 — My Flights vide avec recherche

- **But / état :** empty state explicite sans vol enregistré.
- **Fond / composition :** même carte claire, sheet/surface basse blanche; titre “My Flights”, message “Let’s Fly Somewhere” et instruction “Tap Search to add your next flight”.
- **Interaction / transition :** l’action Search ouvre le flux d’ajout; les tabs restent accessibles et le fond cartographique conserve le contexte.
- **Via / Apple :** empty state réutilisable avec `Button`; la recherche doit être une vraie `Tab(role: .search)`, pas une toolbar custom.

## 3–27 — recherche, résultats et ajout

### Capture 003 — Add Flight, champ initial

- **But / état :** démarrer l’ajout d’un vol par compagnie, aéroport ou numéro.
- **Fond / composition :** carte visible derrière une grande sheet blanche presque pleine hauteur, grand rayon supérieur; titre “Add Flight”, bouton close en haut à droite; clavier système visible.
- **Champs / résultats :** `TextField` actif “Enter airline, airport, or flight”; deux actions secondaires “Find by Route” et “Find by Flight Number”; suggestions `Lion Air`, `Batik Air`, `Soekarno-Hatta Intl.`.
- **Via / Apple :** `MapPresentationSheet`/`adaptiveSheetPresentation`; `TextField` avec `FocusState`, `Button` close et rows de résultats natives.

### Capture 004 — route suggérée et favoris d’aéroports

- **But / état :** champ de recherche vide avec itinéraire récemment utilisé.
- **Fond / composition :** même sheet blanche sur carte, clavier masqué ou réduit; une route `MCO → SJU` et sa date sont dans une ligne d’alternative.
- **Contenu / actions :** sections “Alternatives for My Next Flight”, “Frequently Used”, compagnies et aéroports `SFO`/`LAX`; actions “Find by Route” et “Find by Flight Number” en bas.
- **Via / Apple :** `List`/`LazyVStack` de `SearchResultRow`, sélection par `Button`; date et suggestions viennent du modèle de recents.

### Capture 005 — recherche de l’origine SFO

- **But / état :** l’utilisateur saisit `sfo` pour l’aéroport de départ.
- **Fond / champ :** sheet blanche, clavier système; champ actif avec texte court, cursor/focus bleu et clear affordance.
- **Résultats :** `San Francisco Intl. SFO · KSFO · San Francisco`, une ligne ville `San Francisco Bay Area` avec “3 airports including SFO”, puis “Airport not listed? Send Report”.
- **Via / Apple :** `SearchTokenField` en état `originEditing`, `SearchResultRow`; soumission par le clavier ou tap d’une row, report via `Button`.

### Capture 006 — origine sélectionnée, saisie de l’arrivée

- **But / état :** origine `SFO` validée; l’utilisateur doit entrer la ville/aéroport d’arrivée.
- **Composition :** token gris compact `SFO` à gauche; libellé “Enter arrival city or airport”; champ destination actif; clavier visible et sheet haute.
- **Résultats / actions :** suggestions d’aéroports autour de Jakarta, avec code IATA/ICAO et ville sur deux niveaux; chaque row est tactile.
- **Via / Apple :** `SearchTokenField` avec `originSelected` et focus `.destination`; `TextField` natif, `Button` rows et `accessibilityValue` du token.

### Capture 007 — origine SFO, destination LAX en cours

- **But / état :** cas de référence de saisie tokenisée; `SFO` est confirmé et `lax` est en cours d’édition.
- **Composition :** token gris `SFO`, champ gris extensible `lax` avec curseur bleu après le texte, clear button circulaire gris à droite; clavier système.
- **Résultats :** aéroport exact `Los Angeles Intl. LAX · KLAX · Los Angeles`, ville `Los Angeles` avec “4 airports including LAX”, et variante de lieu `Laxa`; report en bas.
- **Via / Apple :** reproduire le comportement de `R1` avec un vrai `TextField` et `Button` clear; la sélection exacte passe au prochain état, pas à une gesture.

### Capture 008 — route SFO–LAX et choix de date

- **But / état :** origine et destination validées; choisir un vol pour `Fri, 26 Jun`.
- **Fond / composition :** carte plus visible autour d’une sheet réduite; en-tête “Tap flight to add to My Flights”, tokens `SFO`/`LAX` et date.
- **Interaction / transition :** une row de vol ouvre les détails/ajoute; la date ou les tokens permettent de modifier la recherche; tabs restent présents.
- **Via / Apple :** `DatePicker` ou `Menu` date selon le flux; `SearchResultRow` et `NavigationStack`/sheet native.

### Capture 009 — résultats de vols SFO–LAX

- **But / état :** résultats normaux, plusieurs codeshares et compagnies.
- **Fond / contenu :** carte claire derrière sheet; filtre “Codeshares”, menu “All Airlines”; rows avec badge compagnie, numéro `AS 1620`, statut `Departs On Time`, durée/heure et `SFO 6:00AM → LAX 7:07AM`.
- **Interactions :** tap d’un vol pour l’ajouter; menu compagnie filtre la liste; scroll vertical dans la sheet.
- **Via / Apple :** `Menu` mono-niveau, `ScrollView`/`List`, `Button` sur toute la row, status badge réutilisable.

### Capture 010 — vol ajouté à My Flights

- **But / état :** feedback de succès après sélection; un vol est ajouté.
- **Fond / composition :** carte zoomée sur la Californie, sheet basse avec la row `AA 6294`; bandeau “Added to My Flights” et confirmation visible.
- **Interaction / transition :** dismiss ou tap de la row ouvre le détail; la confirmation ne doit pas déplacer la liste de façon imprévisible.
- **Via / Apple :** feedback inline ou `sensoryFeedback`; conserver le detent et la navigation de la sheet existante.

### Capture 011 — calendrier de départ

- **But / état :** choisir une date de départ après les tokens `SFO` et `LAX`.
- **Fond / composition :** grande sheet blanche avec en-tête “Enter departure date”; calendrier mensuel compact affichant juin/juillet 2026 et une date surlignée.
- **Contrôles / transitions :** sélection d’un jour revient aux résultats; bouton retour/fermeture conserve les recherches; pas de clavier.
- **Via / Apple :** `DatePicker` `.graphical` ou `DatePicker` encapsulé dans la sheet; style custom limité à la surface et à l’accent sélectionné.

### Capture 012 — résultats pour le 30 juin

- **But / état :** même route avec une date future précise `Tue, 30 Jun`.
- **Fond / contenu :** sheet de résultats, menu `Codeshares / All Airlines`, plusieurs rows avec dates et horaires; statut normal et codes compagnies visibles.
- **Interaction / transition :** tap ajoute le vol; menu filtre; date de l’en-tête est éditable.
- **Via / Apple :** réutiliser `FlightResultRow` et le même modèle de query; `Menu` natif pour les codeshares.

### Capture 013 — filtre My Flights

- **But / état :** l’utilisateur choisit d’ajouter un vol à `My Flights`.
- **Composition :** en-tête “Tap flight to add to My Flights”; menu codeshares/compagnies et rows avec compteur de minutes avant départ.
- **État / détails :** les horaires sont actualisés; chaque row garde destination, statut et aéroports alignés en colonnes lisibles.
- **Via / Apple :** état d’ajout dans le modèle, `Button` de row; ne pas transformer le filtre en navigation séparée.

### Capture 014 — ajout à Friends’ Flights

- **But / état :** même liste mais destination de sauvegarde `Friends’ Flights`.
- **Composition :** en-tête “Tap flight to add to Friends’ Flights”, tokens `SFO`/`LAX`, date; rows avec compteurs `25 MINUTES` et status.
- **Interaction / transition :** sélection partage le vol avec les amis; l’onglet Friends devient disponible; aucune confirmation modale superflue.
- **Via / Apple :** enum de destination dans l’intention de recherche, pas une copie de l’écran; `Button` et state feedback.

### Capture 015 — vols avec retards dans les résultats

- **But / état :** état normal enrichi de retards: plusieurs vols à l’heure, un vol `40m late`.
- **Composition :** les statuts sont sous les codes compagnies; rouge/orange réservé au retard, minutes et horaires restent noirs/secondaires.
- **Interaction / transition :** tap ouvre un résultat détaillé; le filtre All Airlines reste accessible.
- **Via / Apple :** `FlightStatusBadge` sémantique, `ForEach` rows; test de tri et de rendu disrupted/attention.

### Capture 016 — menu de compagnies ouvert

- **But / état :** filtrer les résultats par compagnie.
- **Composition :** popup/menu natif listant `Aer Lingus`, `Aeromexico`, `Air China`, `Air France`, `Alaska`, `American Airlines`, etc.; le contenu de la liste reste visible derrière.
- **Interaction / transition :** sélectionner une compagnie ferme le menu et filtre; tap hors menu annule.
- **Via / Apple :** `Menu` ou `Picker` avec une seule profondeur; ne pas coder un overlay multi-menu custom.

### Capture 017 — résultat filtré American Airlines

- **But / état :** compagnie `American Airlines` sélectionnée.
- **Composition :** menu de filtre en en-tête; rows `AA 6294`, `AA 6336`, `AA 6428`, `AA 6330`, horaires et durées; statut `Departs On Time`.
- **Interaction / transition :** tap choisit un vol; réouvrir le menu change le réseau/compagnie.
- **Via / Apple :** filtre injecté dans la liste `FlightResultRow`, accessibilité annonce compagnie et numéro avant le statut.

### Capture 018 — résultats initiaux avec modes d’ajout

- **But / état :** retour au champ générique, avec options d’automatisation.
- **Composition :** rows compagnie/aéroport, section “More”, actions “Find by Route”, “Find by Flight Number”, “Sync from Calendar”, “Random Flight”; carte Pro en bas.
- **Interaction / transition :** chaque action lance un sous-flux natif; “Sync from Calendar” mène à l’autorisation/setting.
- **Via / Apple :** `List`/`Section`, `Button`, `Menu` si besoin; `EventKit` seulement dans un repository séparé.

### Capture 019 — saisie de la compagnie

- **But / état :** l’utilisateur a choisi “Enter airline”.
- **Fond / champ :** sheet haute, clavier alphabétique, titre de contexte et champ actif “Enter airline”.
- **Résultats :** liste de compagnies avec nom, code IATA et ICAO (`American Airlines AA·AAL`, `Lion Air JT·LNI`, etc.).
- **Via / Apple :** `TextField` focusé, recherche locale/remote injectée, `SearchResultRow`; type de champ `.textInputAutocapitalization` adapté.

### Capture 020 — compagnie filtrée par AA

- **But / état :** query `AA`, résultats de compagnies proches (`American Airlines`, `Allegiant`, `Asiana`, `Aloha`, etc.).
- **Composition :** clavier visible, rows alignées code/nom, pas de carte ni illustration parasite.
- **Interaction / transition :** sélection confirme le code compagnie et passe au champ de numéro; clear revient à la liste complète.
- **Via / Apple :** état `airlineEditing`, `FocusState`, `Button` result; conserver la suggestion exacte en haut.

### Capture 021 — saisie du numéro de vol

- **But / état :** compagnie `AA` validée; le champ attend le numéro.
- **Composition :** sheet blanche, champ `AA` + curseur; texte d’aide “Tip: Just The Numbers / Not including airline code”; clavier numérique/système.
- **Interaction / transition :** le clavier soumet `292`; validation doit refuser le code répété mais conserver la valeur saisie.
- **Via / Apple :** `TextField` avec `keyboardType` approprié, `.onSubmit`, focus natif et copie d’aide secondaire.

### Capture 022 — numéro détecté

- **But / état :** `AA 292` reconnu.
- **Composition :** champ rempli, row de résultat “American Airlines 292 — Detected flight number”; fond carte/sheet inchangé.
- **Interaction / transition :** tap de la détection passe au choix de date; édition du numéro reste possible.
- **Via / Apple :** `Button` de suggestion; state `flightNumberDetected`, pas d’action automatique sans confirmation.

### Capture 023 — date rapide du vol

- **But / état :** choisir `Today`, `Tomorrow`, ou une date calendrier pour `AA 292`.
- **Composition :** sheet blanche avec en-tête `Enter departure date`, rows `Today` et `Tomorrow` avec dates explicites, puis `Pick from Calendar`.
- **Interaction / transition :** choix rapide lance la recherche; calendrier lance `DatePicker`; le retour garde le numéro.
- **Via / Apple :** `Button` rows + `DatePicker`; pas de date custom pour remplacer le contrôle système.

### Capture 024 — erreur réseau pendant la recherche

- **But / état :** requête `CPT → MEL`, date future; connexion impossible.
- **Composition :** carte visible derrière la sheet; empty/error central “Can’t Connect / Check your internet connection”; action implicite tap anywhere to retry.
- **Interaction / transition :** retry relance le repository, edit search revient aux champs; conserver les tokens et la date.
- **Via / Apple :** `ErrorStateView` avec `Button` “Réessayer”, `Task` annulable; erreur proche de la liste, pas une alerte seule.

### Capture 025 — aucun vol trouvé

- **But / état :** query `OSL → SFO`, aucun résultat.
- **Composition :** en-tête route/date, état “No Flights Found”, explication sur les inputs, CTA “Add Flight Record Manually” et “Edit Search”.
- **Interaction / transition :** manuel ouvre le formulaire 28+; edit revient à l’étape précédente.
- **Via / Apple :** `EmptyStateView` avec deux `Button` hiérarchisés; la sheet adaptative reste le conteneur.

### Capture 026 — vols détournés

- **But / état :** query `DFW → SFO`; résultats avec statut `Diverted to DFW`.
- **Composition :** rows de plusieurs codeshares, code/statut `DIVERTED` très visible en accent rouge/orange; route et heures sont conservées.
- **Interaction / transition :** tap ouvre le détail du vol; filtre codeshares reste disponible.
- **Via / Apple :** condition `.disrupted`/`.diverted`, texte et icône en plus de la couleur; test d’accessibilité du statut.

### Capture 027 — vol trouvé et action manuel

- **But / état :** `AA 292`, `Sat, 27 Jun`, un résultat unique `New York → Delhi`.
- **Composition :** sheet compacte, row de vol avec `Departs On Time`, aéroports `JFK`/`DEL`, CTA `Flight missing? Add Manually` en bas.
- **Interaction / transition :** tap ajoute/ouvre; `Add Manually` ouvre le formulaire; la fermeture revient au planner.
- **Via / Apple :** row et CTA en `Button`, destination navigation/sheet déterminée par le parent.

## 28–42 — saisie manuelle et formulaire détaillé

### Capture 028 — Add Missing Flight initial

- **But / état :** formulaire de secours pour un vol absent du moteur de recherche.
- **Composition :** grande sheet blanche, titre “Add Missing Flight”, explication, carte PRO “Complete Your Map & Stats”; sections `American Airlines AA·AAL`, `Flight Number AA292`, `Departure Date`, `Flight Status Arrived`, puis `DEPARTURE`.
- **Interaction / transition :** chaque row ouvre un éditeur natif; le formulaire est scrollable et conserve le bouton close.
- **Via / Apple :** `Form`/`List` sectionné, `NavigationStack`, `Picker`, `DatePicker`; `ProBenefitCard` custom seulement pour le bénéfice.

### Capture 029 — sélection de compagnie manuelle

- **But / état :** picker “Select Airline”.
- **Composition :** navigation secondaire blanche, titre/back natif; section “Suggestions” avec logos/nom/codes (`Qantas`, `Delta`, `Cathay Pacific`, `Air New Zealand`, etc.).
- **Interaction / transition :** sélection remplit la row précédente et revient; recherche optionnelle reste native.
- **Via / Apple :** `NavigationStack` + `List`/`Picker`; pas de menu de logos codé comme une tab.

### Capture 030 — formulaire avec Cathay

- **But / état :** compagnie `Cathay Pacific CX·CPA`, numéro `CX873`, date initiale.
- **Composition :** formulaire vertical; carte PRO, rows `Flight Number`, `Departure Date`, `Flight Status`, section départ.
- **Interaction / transition :** numéro/date/status sont éditables; scroll mène à arrivée/réservation/aéronef.
- **Via / Apple :** `Form`, `TextField`, `DatePicker`, `Picker`; composants de row partagés avec les settings.

### Capture 031 — date éditée au 28 juin

- **But / état :** édition de `Departure Date` avec valeur 28 juin 2026.
- **Composition :** formulaire sous-jacent visible; picker date avec titre “Departure Date”, confirmation “Done”, date “28 June 2026” et action “Clear Date”.
- **Interaction / transition :** Done commit la date; Clear remet nil/état indéfini; retour système ferme l’éditeur.
- **Via / Apple :** `DatePicker` dans `sheet`/`popover` ou `NavigationStack`; `Button` natif pour clear.

### Capture 032 — date corrigée au 24 juin

- **But / état :** même éditeur avec la date métier changée en `24 June 2026`.
- **Composition :** valeur mise à jour, ligne Done et Clear Date inchangées; le reste du formulaire reste stable.
- **Interaction / transition :** la sélection ne doit pas réinitialiser compagnie/numéro/status.
- **Via / Apple :** modèle de formulaire structuré et binding de `Date`; test de conservation des autres champs.

### Capture 033 — formulaire avec sections départ/arrivée

- **But / état :** formulaire manuel renseigné jusqu’au statut et à la section `DEPARTURE`; `ARRIVAL` est visible plus bas.
- **Composition :** rows de formulaire groupées, labels en petites capitales grises, séparations natives, contenu scrollable.
- **Interaction / transition :** tap d’un champ ouvre son éditeur; le formulaire peut valider progressivement.
- **Via / Apple :** `Form`/`Section`, `LabeledContent`, `NavigationLink` pour les sous-éditeurs.

### Capture 034 — départ renseigné

- **But / état :** départ `San Francisco Intl. SFO·KSFO`, scheduled departure `1:20 AM`, terminal/gate à compléter.
- **Composition :** row aéroport avec icône, horaires et champs `Terminal`, `Gate`; texte secondaire gris, alignements en colonnes.
- **Interaction / transition :** sélection aéroport ouvre recherche de lieu; heure ouvre `DatePicker`/éditeur; gate reste texte court.
- **Via / Apple :** `TextField`, `DatePicker`, `NavigationLink` vers `SearchResultRow`; validation locale.

### Capture 035 — arrivée, réservation et aéronef vides

- **But / état :** sections `ARRIVAL`, `RESERVATION`, `AIRCRAFT` affichées sans données.
- **Composition :** labels de section, rows `Arrival Airport`, `Scheduled Arrival`, `Terminal`, `Gate`, `PNR`, `Seat`, `Seat Type`, `Class`, `Reason`, `Tail Number`, `Aircraft Type`.
- **Interaction / transition :** chaque champ est facultatif, sauf ceux nécessaires à l’identité du vol; scroll conserve les repères.
- **Via / Apple :** `Form` natif, `Picker` pour seat/class/reason, `TextField` pour PNR/tail.

### Capture 036 — arrivée renseignée et réservation

- **But / état :** arrivée `Hong Kong Intl. HKG·VHHH`, `6:17 AM`, terminal 1; PNR `WYA123`, seat `31A`.
- **Composition :** rows groupées, valeur à droite, labels à gauche; le champ seat type reste à choisir.
- **Interaction / transition :** tap Seat Type ouvre l’éditeur; aéroport/heure restent modifiables.
- **Via / Apple :** `LabeledContent`, `Picker`, `DatePicker`, `Button`/`NavigationLink`.

### Capture 037 — picker de siège/type ouvert

- **But / état :** choix de seat type, class et reason.
- **Composition :** menu/picker natif affichant `None`, `Aisle`, `Middle`, `Window`; options de rôle `Pilot`, `Captain`, `Jumpseat` et sections de classe.
- **Interaction / transition :** choix ferme l’éditeur et écrit la valeur; une seule profondeur de menu.
- **Via / Apple :** `Picker` avec style adapté au contexte, `Menu` seulement si un menu compact est préférable.

### Capture 038 — arrivée finale renseignée

- **But / état :** arrivée avec `Scheduled Arrival 6:17 AM`, terminal 1, seat type `Window`, autres metadata encore facultatives.
- **Composition :** formulaire stable; les valeurs choisies sont visibles dans la colonne trailing sans changement de poids typographique.
- **Interaction / transition :** passage à aircraft ou detailed timetable; validation respecte les champs optionnels.
- **Via / Apple :** `Form` + `Picker`/`TextField`; tests de bindings et Dynamic Type.

### Capture 039 — detailed timetable vide

- **But / état :** renseigner les temps opérationnels détaillés.
- **Composition :** section `DETAILED TIMETABLE`, deux colonnes `SCHEDULED` et `ACTUAL`; rows Gate Departure, Taxi Time, Takeoff Time, Landing Time, Taxi Time, Gate Arrival, Air Time, Total Time, Notes.
- **Interaction / transition :** tap d’une valeur ouvre un champ date/heure ou durée; les lignes de calcul restent alignées.
- **Via / Apple :** `Form`/`Grid` accessible; `DatePicker`/`TextField` natifs, calculs dans le modèle.

### Capture 040 — aéronef renseigné

- **But / état :** aircraft `775`, `Boeing 777-300ER`, type ICAO `B77W` ajouté au timetable.
- **Composition :** section aircraft au-dessus de la grille; valeurs en trailing, texte de modèle lisible.
- **Interaction / transition :** tap type ouvre recherche/picker d’aéronef; les temps restent éditables.
- **Via / Apple :** `SearchResultRow` réutilisée pour aircraft, `Picker` si liste bornée; pas de badge custom obligatoire.

### Capture 041 — timetable partiellement renseigné

- **But / état :** scheduled/actual Gate Departure, Gate Arrival et totals sont présents; certaines étapes restent vides.
- **Composition :** colonnes comparables, temps en chiffres tabulaires, `1:20 AM / 1:13 AM`, `6:15 AM / 6:17 AM`, total `13h55`.
- **Interaction / transition :** modification d’une heure recalcule les durées; distinction scheduled/actual par colonne et label, pas seulement couleur.
- **Via / Apple :** modèle de durée testable, `Grid`/`LabeledContent`; respect de Dynamic Type.

### Capture 042 — timetable complet

- **But / état :** détail manuel complet, avec takeoff/landing et total réel.
- **Composition :** header aircraft `Boeing 777-300ER B77W`; grille schedule/actual remplie et notes en bas; surface blanche et marges constantes.
- **Interaction / transition :** Done/close en navigation native; sauvegarde dans le Flight Log.
- **Via / Apple :** `Form`, `DatePicker`, `TextField`, validation du repository; aucun contrôle système redessiné.

## 43–53 — carte, vols enregistrés et météo

### Capture 043 — My Flights vide après ajout passé

- **But / état :** liste future vide mais présence de vols passés; invite à ajouter un vol.
- **Fond / composition :** carte monde/Amériques claire, zone basse avec “Added to Past Flights” puis empty “Let’s Fly Somewhere”; tab bar persistante.
- **Interaction / transition :** Search relance l’ajout; past flights reste un état distinct de future flights.
- **Via / Apple :** `Map` en fond, `EmptyStateView`, `TabView`; séparer `normal`, `emptyFuture`, `pastOnly` dans le modèle.

### Capture 044 — scan en cours

- **But / état :** import/scan de vols en progression; message `Scanning…`.
- **Fond / composition :** carte assombrie ou simplifiée, petit indicateur en haut, tab bar toujours visible; le texte de progression est central et discret.
- **Interaction / transition :** le scan évolue vers résultats ou erreur; ne pas interrompre par une navigation implicite.
- **Via / Apple :** `ProgressView`/skeleton, `Task` cancellable; animation soumise à Reduce Motion.

### Capture 045 — vols multi-segments sur la carte

- **But / état :** deux vols affichés dans la liste: un arrivé et un départ à venir.
- **Fond / composition :** carte Amérique du Nord avec lignes/points; sheet basse `My Flights`; rows `AA 6294` et `PD 2720` avec direction, statut et heures.
- **Interaction / transition :** tap row ouvre le détail; map route sélectionnable; ajout de vol reste accessible.
- **Via / Apple :** `Map(selection:)`, `JourneyMapContent`, `Station/flight card` réutilisable.

### Capture 046 — un vol à venir sur carte locale

- **But / état :** une seule carte de vol `AA 6294`, départ SFO → LAX dans 2 h.
- **Fond / composition :** carte Californie zoomée; sheet basse avec `Departs On Time`, compteur `87 MINUTES`, aéroports et horaires.
- **Interaction / transition :** tap ouvre le flight detail; la carte reste contextuelle et peut être déplacée.
- **Via / Apple :** `Map` + `safeAreaInset`/sheet; minutes en `.monospacedDigit()` pour stabilité.

### Capture 047 — itinéraire multi-vols

- **But / état :** voyage composé de `DL 1421 SFO → LAX`, longue escale, puis `CX 7786 LAX → MEX`.
- **Fond / composition :** carte monde avec arcs, sheet liste par étape; durée d’escale `21h34m at LAX`, label `Long Layover`.
- **Interaction / transition :** tap segment ouvre son vol; résumé route reste groupé comme un trip.
- **Via / Apple :** `ForEach` de segments, `JourneySegmentStrip`; `Map` pour les polylines.

### Capture 048 — liste de vols future

- **But / état :** plusieurs vols planifiés, première vue de la timeline.
- **Composition :** sheet blanche sur carte; rows datées (`DL 1421`, `CX 7786`, `DL 7976`, `BA178`, `QR6554`), durée/jours avant départ et routes.
- **Interaction / transition :** scroll vertical; tap ouvre détail; PRO card si historique > 12 mois.
- **Via / Apple :** `List`/`LazyVStack`, `FlightTimelineRow`, `NavigationStack` ou sheet détaillée.

### Capture 049 — suite de la liste future

- **But / état :** continuation de la timeline avec vols Stockholm–Dubai, Dubai–Cape Town.
- **Composition :** mêmes rows et alignements; les compteurs `DAYS` et codes aéroports sont secondaires mais bien contrastés.
- **Interaction / transition :** même contrat de row; aucune variation visuelle juste parce que la destination change.
- **Via / Apple :** composant `FlightTimelineRow` avec données injectées, chiffres tabulaires.

### Capture 050 — carte de vol isolée

- **But / état :** focus compact sur `AA 6294` à l’heure.
- **Composition :** carte géographique minimale + sheet basse; status `Departs On Time`, `32 MINUTES`, SFO/LAX et heures.
- **Interaction / transition :** tap sheet vers détail; map control non destructif.
- **Via / Apple :** état normal du même `FlightSummaryCard`, pas une deuxième implémentation.

### Capture 051 — Weather Layers Pro

- **But / état :** écran de choix des couches météo.
- **Fond / composition :** carte Californie, grande sheet blanche; titre “Weather Layers”, explication “See what’s coming…”, carte PRO et options `US Radar` / `Global Estimate`.
- **Interaction / transition :** sélection d’une couche met à jour la carte; CTA “Upgrade to Flighty Pro” ouvre la présentation Pro.
- **Via / Apple :** `Picker`/`Menu` pour le mode, `Map` pour le rendu; carte PRO custom + `BeamCTAButton` si CTA IA.

### Capture 052 — Weather Layers avec carte active

- **But / état :** couche météo affichée/choisie avec accès gratuit complémentaire.
- **Fond / composition :** carte plus détaillée avec régions; sheet expose la même explication, badge `PRO`, `US Radar` et `Global Estimate`.
- **Interaction / transition :** tap option change le type de map; actualisation automatique annoncée.
- **Via / Apple :** enum de layer dans le view model, `Map` overlay; animation de changement désactivable avec Reduce Motion.

### Capture 053 — retour à My Flights

- **But / état :** fermeture des couches et retour au vol `AA 6294`.
- **Fond / composition :** carte Californie et sheet basse; status, compteur `31 MINUTES`, route et tab bar identiques à la capture 50.
- **Interaction / transition :** layer reste en contexte carte; le vol conserve son état.
- **Via / Apple :** navigation/dismiss native et état partagé du map shell.

## 54–58 — liste des aéroports

### Capture 054 — Airports, filtres initiaux

- **But / état :** tableau mondial d’état des aéroports, onglet “For You”.
- **Fond / composition :** surface blanche de liste, titre `Airports`, contrôle date `Now`, filtres `For You`, `All`, `Asia`, `North America`, `Europe`; cartes compactes avec pourcentages et temps.
- **Interaction / transition :** tap airport ouvre son détail; filtres sont des menus/segments; scroll.
- **Via / Apple :** `NavigationStack`, `Picker`/`Menu`, `List`, `AirportStatusRow` custom.

### Capture 055 — liste avec problèmes majeurs

- **But / état :** catégorie `Major Issues`; Guangzhou, Shenzhen, Beijing affichent retards et taux.
- **Composition :** rows à deux colonnes départs/arrivées, pourcentage en accent et durée; le groupe “Major Issues” est séparé du groupe For You.
- **Interaction / transition :** tap row détail; filtre date/region reste en haut.
- **Via / Apple :** `Section`, `FlightyStatusBadge`, `Menu` de date; rouge/orange accompagné du texte.

### Capture 056 — contrôle All Day ouvert

- **But / état :** contrôle temporel ouvert pour passer de Now à l’agrégat de la journée.
- **Composition :** menu/popover `Now / All Day`, liste d’aéroports visible derrière, labels `Live status and advisories` et `Overview totals for today`.
- **Interaction / transition :** sélection ferme le menu et recalcule les totaux; tap extérieur annule.
- **Via / Apple :** `Menu` mono-niveau, état sélectionné annoncé; pas de custom dropdown.

### Capture 057 — vue All Day, catégories

- **But / état :** état journalier avec `For You`, `Major Issues`, `Normal Operations`.
- **Composition :** rows d’aéroport avec `ON TIME`, taux départ/arrivée et volumes; catégories donnent une hiérarchie et non une couleur seule.
- **Interaction / transition :** tap aéroport; filtres région/date persistent.
- **Via / Apple :** `List`/`Section`, `Picker`/`Menu`, rows adaptatives Dynamic Type.

### Capture 058 — All Day filtré par région

- **But / état :** `All Day`, `All`, `Asia`, `North America`, avec sections `Major Issues`, `Minor Issues`, `Normal Operations`.
- **Composition :** nombreux rows, statistiques alignées; la liste est dense mais conserve padding et séparateurs fins.
- **Interaction / transition :** sélection d’un aéroport; region/date se modifient sans perdre le scroll si possible.
- **Via / Apple :** `List` native avec `Section`; extraction `AirportStatusRow` et `AirportCategoryHeader`.

## 59–84 — détail aéroport, problèmes et graphiques

### Capture 059 — détail Guangzhou, problèmes majeurs

- **But / état :** fiche `Guangzhou Baiyun Intl.`, code `CAN ZGGG`, `Major Issues`.
- **Fond / composition :** sheet blanche sur contexte carte; header lieu/heure locale; trois grandes cartes `Departures`, `Arrivals`, `Weather`, puis CTA `View Full Operational Report`.
- **Interaction / transition :** cartes ouvrent graphiques/détails; report ouvre une feuille/route détaillée.
- **Via / Apple :** `NavigationStack`, `ScrollView`, `FlightyCard`, `Button`; carte contexte conservée si modal.

### Capture 060 — performance départs et trend de retard

- **But / état :** airport operations avec départs retardés et graphique `Takeoff Delay Trend`.
- **Composition :** header CAN, résumé `1h37m`, légende `On Time / Delayed 15m+ / Canceled`, pourcentages et compteurs; graphique avec axe heures et ligne/zone de délai.
- **Interaction / transition :** tap graphique/legend filtre ou ouvre explication; CTA full report.
- **Via / Apple :** `Chart` si disponible et accessible, sinon composant graph dédié avec summary vocal; `TabView` interdit ici si ce n’est pas une tab de premier niveau.

### Capture 061 — airport intelligence Pro

- **But / état :** état Pro lock pour les advisories/route disruptions.
- **Composition :** header `Normal Operations`, carte “Unlock Airport Intelligence”, explication, CTA `Unlock Pro at 14,000 Airports`; performance en dessous.
- **Interaction / transition :** CTA ouvre paywall; le contenu gratuit reste visible, pas de redirection opaque.
- **Via / Apple :** `ProBenefitCard`, `ShareLink` hors sujet; CTA `Button` avec beam si action IA et Reduce Motion.

### Capture 062 — performance départs et arrivées

- **But / état :** vue normal/retard avec deux sections `Departure Performance` et `Arrival Performance`.
- **Composition :** pourcentages et nombres, graphique départ visible puis graphique arrivée plus bas; légendes constantes.
- **Interaction / transition :** scroll; sélection `Today`/date depuis le menu de la section.
- **Via / Apple :** `ScrollView`, cards de métriques, `Chart` avec une description hors tracé.

### Capture 063 — variation de données du jour

- **But / état :** même aéroport à un autre moment, performance plus normale et départs/arrivées distincts.
- **Composition :** chiffres `55% / 45% / 0%` puis arrivée à `100%`; état `Live Delay` ou Pro associé au graphe.
- **Interaction / transition :** changement de snapshot sans changer la structure; l’actualisation ne doit pas flasher.
- **Via / Apple :** modèle de snapshot daté, skeleton de même taille, `monospacedDigit`.

### Capture 064 — météo actuelle officielle

- **But / état :** `Current Weather` officiel de CAN: 27°, showers, VFR, visibilité 10+ km, vent 4 km/h.
- **Composition :** cartes météo avec icône, température, `Cloud Ceiling`, `Visibility`, `Wind`; section `Daily Performance` et menu `Today`.
- **Interaction / transition :** menu départs/arrivées/totals; météo reste informative.
- **Via / Apple :** `WeatherCard` custom, `Menu` pour la métrique; valeurs avec labels d’accessibilité complets.

### Capture 065 — météo verrouillée Pro

- **But / état :** conditions avancées non disponibles, carte Pro “Unlock Airport Conditions”.
- **Composition :** weather header, badge PRO et explication sur visibilité/règles de vol; dessous `Daily Performance`.
- **Interaction / transition :** CTA paywall, retour conserve le jour sélectionné.
- **Via / Apple :** custom seulement pour surface Pro; `Button`, `Menu`, sheet native.

### Capture 066 — performance journalière et routes perturbées

- **But / état :** `Friday, June 26`, 789 départs; ratios on-time/delayed/canceled et routes les plus perturbées.
- **Composition :** métriques en cartes, légende, liste/mini-map de codes `SHA`, `HGH`, `KMG`, etc.; `Show More` trailing.
- **Interaction / transition :** Show More ouvre la liste détaillée des routes; date menu change le snapshot.
- **Via / Apple :** `Button` full row, `NavigationLink`/sheet de détail, graph/route badge réutilisable.

### Capture 067 — autre jour avec verrou Pro

- **But / état :** performance du dimanche, données moins perturbées mais liste de routes verrouillée.
- **Composition :** `783 Departures`, 93% on time, 6% delayed, 1% canceled; CTA `Get Flighty Pro` sous “Which routes…”.
- **Interaction / transition :** upgrade ou date change; le verrou ne cache pas les totaux de base.
- **Via / Apple :** état `proLocked` dans la carte, `Button` accessible, pas de texte tronqué.

### Capture 068 — routes et compagnies les plus perturbées

- **But / état :** deux listes analytiques: `Which routes are most disrupted?` et `Which airlines are most disrupted?`.
- **Composition :** cartes avec code, compte et pourcentage; `Show More` pour chaque liste; couleurs delayed/canceled légendées.
- **Interaction / transition :** chaque Show More ouvre un détail filtré; le header airport reste dans le parcours.
- **Via / Apple :** deux `Section`s, `NavigationLink` ou sheet, `Chart`/table accessible.

### Capture 069 — Runway Regulars et Airport Stats vides

- **But / état :** aucune visite utilisateur/ami de CAN; stats disponibles.
- **Composition :** sections `Runway Regulars` avec message “You and your friends haven’t flown through this airport”, puis `Airport Stats` avec départs, compagnies, airports/countries served; graphique de compagnies.
- **Interaction / transition :** Share et détail de stats; empty social n’empêche pas les chiffres publics.
- **Via / Apple :** `EmptyStateView` inline, `ShareLink`, `List`/cards.

### Capture 070 — Runway Regulars avec amis

- **But / état :** JFK avec amis `Alex 2 visits`, `Sam 1 visit`.
- **Composition :** header `John F Kennedy`, bouton `Share`; avatars/initiales dans la carte sociale, stats dessous.
- **Interaction / transition :** tap ami ouvre profil/vols; Share utilise le système.
- **Via / Apple :** `ShareLink`, `Button` rows, `NavigationStack`; avatar custom mais label vocal.

### Capture 071 — Airport Stats détaillées

- **But / état :** statistiques CAN: 789 départs, 68 compagnies, 183 aéroports, 40 pays; routes principales.
- **Composition :** grands nombres en grille, graphique `Busiest Airlines`, liste `Busiest Routes` avec codes/noms/nombre de vols.
- **Interaction / transition :** `Show More` ouvre listes complètes; rows de route navigables.
- **Via / Apple :** `LazyVGrid` responsive, `List`, `Button`/`NavigationLink`, chiffres tabulaires.

### Capture 072 — suite des routes principales

- **But / état :** continuation de la liste `Busiest Routes` jusqu’à Nanjing; même snapshot.
- **Composition :** rows homogènes, code en badge, nom complet, `FLIGHTS` en secondaire; `Show More` final.
- **Interaction / transition :** tap route ouvre analyse; scroll reste fluide.
- **Via / Apple :** `BusiestRouteRow` réutilisable; `List`/`ScrollView` natif.

### Capture 073 — départs par heure, aujourd’hui

- **But / état :** tableau live des départs CAN, filtre `Today`, destination/all airline, gate, gravité.
- **Composition :** header avec Share, menu `Today`, `To`, `Airline`, légende `On Time / 15m Late / 45m Late / Canceled / Diverted`; rows `Dubai EK9871`, `Shanghai 9C8856`, etc.
- **Interaction / transition :** filtres natifs, tap row détail, `Show Earlier Flights` recharge l’historique.
- **Via / Apple :** `Menu`/`Picker`, `List`, `DepartureRow`; MapKit seulement si une carte est visible.

### Capture 074 — performance départs aujourd’hui

- **But / état :** même tableau avec filtre/onglet `Departure Performance`.
- **Composition :** résumé des catégories de performance en haut; rows avec gate et retard; mêmes alignements temporels.
- **Interaction / transition :** changer le mode de métrique ne change pas le composant de row.
- **Via / Apple :** `Picker` segmenté ou `Menu` selon largeur; `List` native.

### Capture 075 — menu de date Today ouvert

- **But / état :** choisir `Today`, `Tomorrow`, `Yesterday` pour les départs.
- **Composition :** contrôle date en haut, menu visible; liste live derrière avec statuts et gates.
- **Interaction / transition :** choix met à jour la liste; la date sélectionnée reste visible dans le label du menu.
- **Via / Apple :** `Menu` mono-niveau ou `Picker`; ne pas dessiner une popover de calendrier si trois options suffisent.

### Capture 076 — départs d’hier

- **But / état :** liste historique `Yesterday`, flights `Departed`, `Unknown`, `Departed On Time`, early/late.
- **Composition :** same legend, heures du passé, gates; rows distinguent les statuts par icon + texte.
- **Interaction / transition :** tap ouvre détail; date menu et destination restent actifs.
- **Via / Apple :** état temporel du même `DepartureRow`; `ProgressView` absent en état chargé.

### Capture 077 — destination picker et codes rapides

- **But / état :** filtrer les départs par destination.
- **Composition :** menu `All Destinations`, champ/quick destinations `B`, `S`, `JKT`, `LON`, `MOW`, `NYC`, `OSA`, `PAR`, `SEL`, `TYO`, `YTO`; liste de vols dessous.
- **Interaction / transition :** tap code filtre; une seule profondeur; reset possible.
- **Via / Apple :** `Menu`/`Picker` avec `searchable` si liste longue; `Button` code seulement si le menu natif ne suffit pas.

### Capture 078 — destination filtrée et reset

- **But / état :** destination sélectionnée, filtre actif, aucune ambiguïté sur l’état.
- **Composition :** quick-code row, libellé `Reset Filters`, un snapshot d’heure/gate; reset visible près du filtre.
- **Interaction / transition :** Reset rétablit All Destinations et les statuts; filtre est annoncé par VoiceOver.
- **Via / Apple :** `Button` reset, `Menu` selection; état de filtre dans le view model.

### Capture 079 — résultat unique filtré NYC

- **But / état :** `Yesterday → NYC`, un seul départ `CZ 699`, gate `A149`, 15m late.
- **Composition :** header filtre + légende, row unique, footer “1 flight from CAN”, `Reset Filters`.
- **Interaction / transition :** tap ouvre le détail du vol; reset remet le tableau.
- **Via / Apple :** `Empty/one-result` variant du même `DepartureRow`, action `Button`.

## 80–84 — graphiques et rapport opérationnel

### Capture 080 — explication du graphe de capacité

- **But / état :** expliquer le graphique `When The Airport Gets Busy` avant ou sous la visualisation horaire.
- **Composition :** header CAN, légende de performance, grandes barres par heure; texte indique que les barres hautes signifient plus de vols et que vert/orange/rouge représentent la santé du trafic.
- **Interaction / transition :** bouton/chevron “See” ou scroll vers le graphe; aucune action cachée dans l’illustration.
- **Via / Apple :** `Chart` avec `accessibilityChartDescriptor`, `Button` d’aide si nécessaire; motion réduite pour les barres animées.

### Capture 081 — détail normal et favoris aéroport

- **But / état :** CAN en `Normal Operations`, arrivées/départs sans problème, météo showers.
- **Composition :** header, carte de résumé `Arrivals & Departures`, météo, CTA report; performance départs et trend; en bas actions `Favorite` et `Favorite with Alerts`.
- **Interaction / transition :** favorite simple ou avec alertes; l’action d’alerte ouvre les préférences, pas une gesture.
- **Via / Apple :** `Toggle`/`Button` selon le modèle favori; `Menu` de report; `adaptiveSheet` pour la préférence.

### Capture 082 — variation normal avec graphe

- **But / état :** même fiche normal à un autre instant, taux `55%/45%/0%`.
- **Composition :** résumé opérationnel stable, trend en dessous, actions de favori; la donnée change sans modifier les espacements.
- **Interaction / transition :** actualisation/polling met à jour les chiffres; skeleton garde la hauteur.
- **Via / Apple :** view model snapshot + `Chart`/card réutilisable; chiffres `.monospacedDigit()`.

### Capture 083 — Airport Operations Report

- **But / état :** rapport textuel complet et lisible par section.
- **Fond / composition :** surface unie claire, titre `Airport Operations Report`; sections `DEPARTURES`, `ARRIVALS`, `WEATHER`, `FUTURE CONDITIONS`, chacune avec résumé, marqueur de sévérité et explication en prose.
- **Interaction / transition :** scroll; retour au détail via navigation/sheet native; pas de graphe requis pour comprendre le message.
- **Via / Apple :** `ScrollView`, `Section`, `Text` accessible; `NavigationStack`/`sheet` selon largeur.

### Capture 084 — routes les plus perturbées, détail

- **But / état :** tableau complet des routes avec délais/annulations départ et arrivée.
- **Composition :** titre “Which routes are most disrupted?”, colonnes `Departures`, `Arrivals`, `DELAYED`, `CANCELED`, grille de codes et pourcentages; long contenu vertical.
- **Interaction / transition :** tap route ouvre une fiche filtrée; la grille peut proposer `Show More`.
- **Via / Apple :** table/`LazyVGrid` custom accessible, `NavigationLink`/`Button`, descriptions vocales par ligne plutôt qu’un graphique illisible.

## 85–115 — détail de vol, actions et saisie de données

### Capture 085 — vol en approche, retard d’arrivée

- **But / état :** `AA 6260`, Los Angeles → San Francisco, “Landing in 40m”, arrivée à la gate dans 1 h 8 m et retards SFO.
- **Fond / composition :** carte de la côte ouest en haut; sheet/detail blanc avec header route, timeline LAX → SFO, heures, terminal/gate et status `4m Early`/`8m Late`.
- **Interaction / transition :** tap segment/aéroport ouvre l’aéroport; carte ou flight actions restent disponibles.
- **Via / Apple :** `FlightDetailView`, `JourneySegmentStrip`, MapKit route; chiffres tabulaires et statuts sémantiques.

### Capture 086 — vol à venir et avion entrant

- **But / état :** `AA 6294`, départ dans 7 h 35 m; inbound aircraft en vol et assez de temps pour le départ.
- **Composition :** carte Californie, header flight, timeline SFO/LAX; départ `B22`, `On Time`, terminal 1, arrivée terminal 4; CTA Pro.
- **Interaction / transition :** scroll vers actions/features, tap aéroport ou détail inbound.
- **Via / Apple :** map + sheet existante, `FlightStatusBadge`, `ProBenefitCard`; pas de contrôles map dessinés.

### Capture 087 — changement de départ

- **But / état :** `DL 1421`, départ changé à 10:15 AM, une heure vingt plus tard.
- **Composition :** carte SFO/LAX, header `My Flight`, grande alerte de changement; rows scheduled pour SFO/LAX avec terminal/gate.
- **Interaction / transition :** ouvrir les alternatives, activer notifications ou consulter le détail; l’alerte est lisible sans couleur seule.
- **Via / Apple :** `FlightAlertCard` custom, `Button` actions, `sheet` détail; notifier le changement via texte/accessibility.

### Capture 088 — changement + calendrier sync

- **But / état :** même changement avec carte d’activation `Calendar Sync`.
- **Composition :** header flight, status change, deux aéroports, puis carte “Enable popular features: Calendar Sync — Add flights automatically. Keep calendar times accurate. All private and on-device.” avec bouton `ENABLE`.
- **Interaction / transition :** Enable ouvre le parcours EventKit; alternatives et share sont disponibles dans l’en-tête/toolbar.
- **Via / Apple :** `Button`, `EventKit` derrière un service; surface Flighty custom, permission Apple native.

### Capture 089 — actions de vol visibles

- **But / état :** menu d’actions du vol changé: `Alternatives`, `Live Activity`, `Open In Maps`.
- **Composition :** même header et carte Calendar Sync; actions sous forme de rows/CTA compactes, texte noir et icônes SF Symbols.
- **Interaction / transition :** Alternatives ouvre les résultats, Live Activity ouvre réglages/permission, Open In Maps utilise Maps.
- **Via / Apple :** `Menu` ou `contextMenu` pour actions secondaires, `Map`/`openURL`/`MapItem` natifs; ne pas créer une toolbar flottante.

### Capture 090 — vol normal avec carte Pro

- **But / état :** `AA 6294` à l’heure, départ dans 7 h 35 m, carte d’activation Calendar Sync.
- **Composition :** carte locale, header route, départ `B22 On Time`, arrivée `1m Early`, CTA Pro et carte Calendar Sync.
- **Interaction / transition :** mêmes actions que 86/88; status normal et CTA Pro coexistent sans conflit.
- **Via / Apple :** `FlightDetailView` configurable par `FlightCondition.normal`; `Button`/`NavigationLink` natifs.

### Capture 091 — metadata booking et météo

- **But / état :** détail route avec activation Calendar Sync, puis champs `Booking Code`, `Seat` et section `Good to Know`.
- **Composition :** rows tappables `Tap to Edit`, météo de départ; le formulaire reste scrollable sous le header compact.
- **Interaction / transition :** tap Booking Code/Seat ouvre l’éditeur clavier; `Review Weather` ouvre météo détaillée.
- **Via / Apple :** `TextField`, `FocusState`, `List`/`Form`, `NavigationLink`; clear/save natifs.

### Capture 092 — Good to Know complet

- **But / état :** détails informatifs: météo départ/arrivée, aucun changement de timezone, Live Activities.
- **Composition :** cartes/rows `Departure Weather`, `Arrival Weather`, `No Timezone Change`, puis carte `Live Activities — The future of notifications`.
- **Interaction / transition :** tap Live Activities ouvre Settings; textes explicatifs ne sont pas des boutons si non actionnables.
- **Via / Apple :** `Section`/`NavigationLink`, `Toggle` dans les réglages, Dynamic Type.

### Capture 093 — prévision d’arrivée Pro

- **But / état :** `Arrival Forecast PRO`, performance de `AA 6294` sur 60 jours; statistiques de retard et carte “NO ISSUE”.
- **Composition :** header flight, carte métrique 80% on time, 0% delays/canceled/diverted; résumés colorés et texte “aircraft is en route”.
- **Interaction / transition :** CTA Pro ouvre le paywall; scroll vers autre détail.
- **Via / Apple :** `Chart`/métriques accessibles, `ProBenefitCard`, state `forecastAvailable`/`proLocked`.

### Capture 094 — état No Issue et vol suivant

- **But / état :** message rassurant “NO ISSUE — Looking good!” puis chaîne de vols/overnight.
- **Composition :** header, carte verte/neutral `NO ISSUE`, texte court; section `This Flight On Time`, prochain segment `Los Angeles → San Francisco`, compteur d’arrivée et lien `Show More Flights`.
- **Interaction / transition :** Show More ouvre la timeline; tap segment ouvre son détail.
- **Via / Apple :** `FlightConditionCard`, `Button`/`NavigationLink`, couleur verte accompagnée du titre.

### Capture 095 — detailed timetable d’un vol

- **But / état :** horaires scheduled/estimated pour départ, taxi, takeoff, landing, arrivée et totals.
- **Composition :** titre flight, grille deux colonnes, heures `6:00 AM`, `6:24 AM`, `7:32 AM`, `7:42 AM`; total scheduled/estimated.
- **Interaction / transition :** lecture uniquement ou tap pour les détails; valeurs tabulaires alignées.
- **Via / Apple :** `Grid`/`LabeledContent`, `Chart` non nécessaire; description VoiceOver par étape.

### Capture 096 — compagnie et historique de route

- **But / état :** `American Airlines`, réseau Oneworld, téléphone/site/social; historique `SFO > LAX` vide.
- **Composition :** logos/icônes contact, carte `My History on This Route`, distance, flight time, `No past flights`, updates et notes.
- **Interaction / transition :** téléphone/site utilisent `openURL`; social/notes peuvent naviguer; Pro lock si besoin.
- **Via / Apple :** `Link`/`Button`, `ShareLink` séparé, `NavigationStack`; pas de fausse WebView sans nécessité.

### Capture 097 — mises à jour et prédictions

- **But / état :** timeline de 27 updates, estimations/prédictions powered by FlightAware Foresight.
- **Composition :** rows horodatées, type `Predicted Take Off`, `Estimated Gate Arrival`, `Estimated Landing`; provenance affichée en petit.
- **Interaction / transition :** scroll; report data issue et notes accessibles depuis actions.
- **Via / Apple :** `TimelineView` custom ou `LazyVStack`, status source en texte; `ProgressView` seulement pendant le chargement.

### Capture 098 — menu d’actions du vol

- **But / état :** feuille/menu `DL 1421` avec actions: Notes, Share Flight, Change to Friend’s Flight, Include in Live Activities, View Pro Benefits, Delete, Report Data Issue.
- **Composition :** surface blanche sur carte, header route en haut; actions en rows suffisamment espacées, destructive en bas.
- **Interaction / transition :** chaque action mène à une sheet/navigation/dialog dédiée; Delete demande confirmation.
- **Via / Apple :** `Menu`/`confirmationDialog`, `ShareLink`, `Toggle`/setting Live Activity; actions secondaires contextuelles.

### Capture 099 — flight detail avec toutes les actions

- **But / état :** vol imminent, inbound arrivé, détail opérationnel complet.
- **Composition :** carte, header `AA 6294`, départ `B22 On Time`, arrivée `Terminal 4`; rows `Alternate Flights`, `Contact Airline`, `Open In Maps`, `Live Activity`, `Move To Friends`, `Calendar times`, `Report Data Issue`, `Delete Flight`.
- **Interaction / transition :** rows naviguent ou ouvrent système; suppression destructive confirmée; l’action principale reste visuellement claire.
- **Via / Apple :** `List`, `Menu`, `ShareLink`, `confirmationDialog`, `Map`/`openURL`; aucune gesture sur les rows.

### Capture 100 — alternate flights

- **But / état :** liste d’alternatives SFO–LAX pour le 29 juin.
- **Composition :** sheet blanche “Alternate Flights”, tokens route/date, menu `Codeshares / All Airlines`, rows horaires/statuts.
- **Interaction / transition :** sélectionner remplace ou ajoute le vol; back/dismiss conserve le détail d’origine.
- **Via / Apple :** `NavigationStack`/`sheet`, `Menu`, `FlightResultRow` partagé avec recherche.

### Capture 101 — Live Activity activée

- **But / état :** détail flight avec contrôle `Live Activity` on/off.
- **Composition :** rows de vol, terminal/gate, Alternate Flights; ligne `Live Activity` avec état `On` et switch/chevron.
- **Interaction / transition :** toggle demande l’autorisation nécessaire ou met à jour la préférence; aucune animation obligatoire.
- **Via / Apple :** `Toggle`, ActivityKit derrière un service; `accessibilityValue` on/off.

### Capture 102 — réglages Live Activity et notifications

- **But / état :** préférences détaillées affichant `Live Activity`, `Calendar times`, `On Device`/`Off` selon chaque option.
- **Composition :** même flight header et liste d’actions, valeurs trailing; spacing de réglages natif.
- **Interaction / transition :** Toggle indépendant par option; retour conserve les valeurs.
- **Via / Apple :** `Toggle`, `Section`, `NavigationStack`; pas de custom switch.

### Capture 103 — amis, filtre Everyone/Today

- **But / état :** onglet Friends avec une row de vol d’un ami.
- **Composition :** carte locale en fond, header `Friends`, filtres `Everyone`/`Today`, CTA `Add Friend`; row `UA 2127` avec statut et SFO/LAX.
- **Interaction / transition :** Add Friend ouvre invitation; tap vol ouvre détail partagé; filtres natifs.
- **Via / Apple :** future tab `Stations/Lignes/Moi` n’imite pas cette tab; la fonction sociale vit dans `Moi` ou un parcours secondaire.

### Capture 104 — suppression d’un vol partagé

- **But / état :** action destructive sur `WN 4970`; suppression le retire aussi des Flighty Friends.
- **Composition :** détail compact avec historique de route, message explicatif, buttons `Cancel` et `Delete Flight`.
- **Interaction / transition :** confirmation ferme ou supprime; message explicite d’impact social.
- **Via / Apple :** `confirmationDialog`/`alert` avec `.destructive`; ne pas supprimer sur un tap accidentel.

### Capture 105 — booking details vide

- **But / état :** éditeur de réservation sans valeur.
- **Composition :** sheet/toolbar `Booking Details Done`; fields `Booking Code`, `Seat`, `Seat Type`, `Class`, `Reason`; clavier QWERTY visible.
- **Interaction / transition :** focus sur un champ, Done commit; pickers de seat/class peuvent ouvrir un menu natif.
- **Via / Apple :** `Form`/`TextField`, `FocusState`, `Picker`, `.toolbar(placement: .keyboard)`.

### Capture 106 — booking details rempli

- **But / état :** code `ABC123`, seat `15A`, options seat type/class/reason visibles.
- **Composition :** même sheet, valeurs trailing; catégories visuellement séparées.
- **Interaction / transition :** tap valeur réédite; Done ferme et revient au flight detail.
- **Via / Apple :** bindings de formulaire et `Picker`; texte de valeurs accessible.

### Capture 107 — choix de classe/reason

- **But / état :** sélection de `Premium Economy`, reason `Personal/Business/Crew`.
- **Composition :** radio/choice rows natifs ou menu; l’option active a un check/état accent, pas une typographie différente.
- **Interaction / transition :** choix immédiat puis retour; annuler conserve l’ancienne valeur.
- **Via / Apple :** `Picker`/`Menu`, `accessibilityAddTraits(.isSelected)` si surface custom.

### Capture 108 — résumé Good to Know après booking

- **But / état :** flight detail avec `COPY`, booking code/seat/class et résumé météo/retards des deux aéroports.
- **Composition :** header `AA 6294`, ligne `ABC123 · 15A · Premium Economy`; sections `SFO Normal Operations`, departure delays/weather, `LAX Normal Operations`, arrival delays/weather, timezone.
- **Interaction / transition :** Copy utilise le presse-papiers système avec feedback; tap airport ouvre détail.
- **Via / Apple :** `Button` copy + `UIPasteboard` wrapper, `NavigationLink`, cards Flighty.

### Capture 109 — note vide

- **But / état :** éditeur `Note` avec clavier.
- **Composition :** titre `Note`, bouton `Done`, champ textuel vide et clavier QWERTY; pas de décoration parasite.
- **Interaction / transition :** saisie puis Done sauvegarde; focus automatique seulement si l’utilisateur a explicitement lancé l’éditeur.
- **Via / Apple :** `TextField`/`TextEditor`, `FocusState`, keyboard toolbar, Dynamic Type.

### Capture 110 — note saisie

- **But / état :** note courte “Nice” dans l’éditeur.
- **Composition :** même layout, texte noir, Done en haut; clavier encore visible selon focus.
- **Interaction / transition :** Done commit; fermeture interactive demande éventuellement conservation si texte modifié.
- **Via / Apple :** `TextEditor` et binding; aucune gesture custom.

### Capture 111 — note affichée dans le détail

- **But / état :** `Nice` sauvegardé dans la section Notes, avec historique updates et report.
- **Composition :** header flight, route history, `Updates`, section `Notes` texte court, `Report Data Issue`.
- **Interaction / transition :** tap note réouvre l’éditeur; report ouvre 112.
- **Via / Apple :** `NavigationLink`/`Button`, `Form` sheet pour l’édition.

### Capture 112 — Report Data Issue, catégories

- **But / état :** formulaire de signalement pour `WN4970`.
- **Composition :** titre close `Report Data Issue`, explication; sections `Delay or Cancellation`, `Terminal or Gate`, `Aircraft`; rows à choix.
- **Interaction / transition :** sélection d’un problème mène au champ complémentaire ou active submit; l’état sélectionné est visible.
- **Via / Apple :** `List`/`Form`, `Picker`/`Button`, `TextEditor` pour details; sheet adaptative.

### Capture 113 — Report Data Issue, suite

- **But / état :** options `Gate is wrong or missing`, `Departure status`, `Arrival status`, `Aircraft type`, `Tail number`, `Other issue` et zone libre.
- **Composition :** scroll vertical, labels de sections et champ `ANYTHING ELSE WE SHOULD KNOW?`.
- **Interaction / transition :** tap option puis saisir détail; submit ouvre thank-you 115.
- **Via / Apple :** `Form`, `TextEditor`, validation de l’option; message d’erreur au champ si nécessaire.

### Capture 114 — report avec choix actif

- **But / état :** `Other issue`/zone de détail active.
- **Composition :** même formulaire, valeur sélectionnée accentuée, clavier possible en bas; CTA d’envoi proche du champ.
- **Interaction / transition :** submit envoie un payload minimal; retour conserve la confidentialité annoncée.
- **Via / Apple :** `TextEditor`, `Button`, `FocusState`, `sensoryFeedback` si utile.

### Capture 115 — confirmation de signalement

- **But / état :** succès “Thank You”; l’envoi est terminé.
- **Composition :** surface claire simple, titre et explication indiquant que le rapport aide Flighty et ne contient pas l’email.
- **Interaction / transition :** close/done revient au détail; pas de CTA concurrent.
- **Via / Apple :** `ContentUnavailableView`/empty-like custom, `Button` Done et dismiss native.

## 116–123 — partage et stickers

### Capture 116 — choix du mode de partage

- **But / état :** `Choose How to Share`, un vol arrive bientôt; sélectionner des vols ou ajouter un ami.
- **Fond / composition :** carte monde/Californie avec sheet basse; texte explicatif; boutons `Add Flighty Friend` et `Choose Flights`.
- **Interaction / transition :** Add Friend ouvre l’invitation; Choose Flights ouvre la sélection 117.
- **Via / Apple :** `ShareLink` pour le partage final, mais écran de choix custom avec `Button` rows; carte conservée.

### Capture 117 — sélection d’un vol à partager

- **But / état :** liste d’un vol `EI337 Berlin → Dublin`; bouton `Choose flights`, action Continue.
- **Composition :** carte Europe, row flight et checkbox/selection; CTA `Continue` en bas.
- **Interaction / transition :** sélectionner active Continue; la suite ouvre les formats de partage.
- **Via / Apple :** `List` + `Button`/selection state, `ShareLink` après validation.

### Capture 118 — choix confirmé

- **But / état :** même vol sélectionné, transition vers les types de partage.
- **Composition :** row avec sélection visible, footer/CTA; map et tabs/sheet gardent le contexte.
- **Interaction / transition :** Continue mène à 119; back désélectionne ou revient.
- **Via / Apple :** `NavigationStack` ou `sheet` item, pas de flag route dispersé.

### Capture 119 — partage du statut en direct

- **But / état :** `Share Flight` avec option `Live Flight Tracking`.
- **Composition :** carte Europe et sheet blanche; titre, texte “Share this link…”, carte Flight Status avec `Track EI337 to Dublin` et URL live.
- **Interaction / transition :** Share ouvre le système; le lien montre status en temps réel.
- **Via / Apple :** `ShareLink` avec `item`/`message`; URL générée par domaine, pas par la vue.

### Capture 120 — partage en texte brut

- **But / état :** format `Plain Text`, détails courants du vol.
- **Composition :** texte monospacé/structuré: Aer Lingus 337, date, BER/DUB, heures/timezones, status, terminal/gate, updates URL; surface scrollable.
- **Interaction / transition :** Share natif; retour choisit un autre format.
- **Via / Apple :** `ShareLink` et `AttributedString`/plain string; contenu vocal lisible.

### Capture 121 — partage route map

- **But / état :** format `Route Map`, “Show your flight story”, sticker boarding pass personnalisable.
- **Composition :** carte d’Europe avec trajet, preview visuelle, bouton share; fond et card gardent marges.
- **Interaction / transition :** personnalisation ouvre editor; Share système exporte l’image/payload.
- **Via / Apple :** `ShareLink` si item `Transferable`; `ImageRenderer` seulement pour la preview générée.

### Capture 122 — boarding pass sticker

- **But / état :** preview boarding pass ultra-réaliste `ALEX SMITH`, `EI337 BERLIN → DUBLIN`, departure/date/seat/class.
- **Composition :** carte illustrée structurée comme un boarding pass, titre `Boarding Pass`, CTA share; déco non interactive.
- **Interaction / transition :** tap share; options de sticker peuvent être un `Menu`/Picker.
- **Via / Apple :** composant visuel custom, partage natif; illustration accessibility label complète.

### Capture 123 — sticker Flight Status

- **But / état :** format `Flight Status`, annoncer arrivée ou retard avec une pastille `EI337 Dublin` et état boarding.
- **Composition :** carte Europe derrière, preview sticker avec heure `9:45PM`, route et status; surface de partage.
- **Interaction / transition :** Share/export; retour aux modes.
- **Via / Apple :** `ShareLink`, composant `StatusSticker`, animation optionnelle réduite.

## 124–129 — amis, invitations et empty states

### Capture 124 — Friends vide

- **But / état :** aucun ami ni vol partagé.
- **Fond / composition :** carte Asie/océan; surface basse `Friends`, filtres `Everyone`/`Today`, CTA `Add Friends’ Flights`; message “Add a Flighty friend… or tap Search to add a flight”.
- **Interaction / transition :** Add Friend ouvre invite; Search ouvre la recherche; tabs My Flights/Friends/Passport restent visibles dans la référence.
- **Via / Apple :** `EmptyStateView`, `Button`, `TabView` Via avec `Moi` pour l’accès social; pas de barre nav custom.

### Capture 125 — Friends avec vols

- **But / état :** un ami a des vols futurs; filtre Everyone/Today.
- **Composition :** carte Amérique du Nord, header Friends, `Add Friend`, rows `Departs On Time` et `CX7500`; nom/route/horaires.
- **Interaction / transition :** tap flight ouvre détail partagé; Add Friend ouvre invite; filtres gardent leur sélection.
- **Via / Apple :** `List`/rows, `NavigationStack`, `Menu`/`Picker` pour filtre.

### Capture 126 — invitation Flighty Friends

- **But / état :** page explicative avant d’envoyer/recevoir une invitation.
- **Composition :** carte sombre/bleutée derrière sheet; titre `Flighty Friends`, texte sur partage automatique, carte, live updates, expiration 48h; nom/cible `MIKE` et CTA.
- **Interaction / transition :** accept/invite; la copie explique le contrôle et la révocation.
- **Via / Apple :** `NavigationStack`/sheet, `Button`, `ShareLink` pour lien d’invitation; confidentialité dans le texte.

### Capture 127 — accepter l’invitation de Sam

- **But / état :** écran de consentement `Sam Wants to Share Flights With You`.
- **Composition :** carte Californie, explication bénéfices + contrôle utilisateur, bouton `Accept Invite` proéminent.
- **Interaction / transition :** accept mène à 129; dismiss/refuse doit rester possible via close/back.
- **Via / Apple :** `Button` avec label d’accessibilité, `confirmationDialog` si refus destructif; sheet native.

### Capture 128 — invitation avec avatars Sam/Alex

- **But / état :** même consentement avec représentation des deux personnes.
- **Composition :** tokens/avatar `Sam`, `Alex`, texte de partage; CTA accept; map en arrière-plan.
- **Interaction / transition :** accept crée la relation; avatars sont informatifs, pas des controls si non tapables.
- **Via / Apple :** `NavigationStack`, `Button`; custom avatar avec `accessibilityLabel`.

### Capture 129 — relation créée

- **But / état :** confirmation “You’re Now Sharing Flights” avec Sam.
- **Composition :** carte, titre et texte sur vols/trips/live updates; CTA `Customize Alerts for This Friend`.
- **Interaction / transition :** CTA ouvre le parcours 164/165; close revient à Friends.
- **Via / Apple :** success state réutilisable, `Button`, navigation vers `ManageFriendView`.

## 130–156 — Passport, statistiques et partage de profil

### Capture 130 — Friends vide dans une vue carte

- **But / état :** aucun ami n’a de vol actif; invitation possible.
- **Composition :** carte Californie, header Friends filtres Everyone/Today, `Sam`/Add Friend contextuel, PRO map/stats card; empty “No One Has Any Flights”.
- **Interaction / transition :** Search ajoute/tracke un vol; Add Friend invite; le message n’est pas une erreur.
- **Via / Apple :** `EmptyStateView`, `Button`, map shell partagé.

### Capture 131 — Passport vide

- **But / état :** statistiques globales sans vol (`All-Time`, `0 km`, `0 airports`, `0 airlines`).
- **Fond / composition :** carte monde; surface Passport avec en-tête `All-Time`, titre `ALL-TIME FLIGHTY PASSPORT`, grands KPI et actions `All Flight Stats`/`All Delay Stats`.
- **Interaction / transition :** filtres All-Time/année, tap stats ouvre les écrans détaillés.
- **Via / Apple :** `NavigationStack`, `Picker`/`Menu` année, `LazyVGrid` KPI.

### Capture 132 — Passport 2026 rempli

- **But / état :** 27 vols, 128 714 km, 7d1h, 14 airports/airlines, 11 long haul.
- **Composition :** gros chiffres, progression around-the-world, minutes lost from delays, aircraft summary; map monde derrière.
- **Interaction / transition :** `All Flight Stats`, `All Delay Stats`, aircraft details; année `2026` sélectionnable.
- **Via / Apple :** `StatsHeader`, `MetricGrid`, `NavigationLink`; chiffres tabulaires, description vocale des unités.

### Capture 133 — Passport, avions et past flights

- **But / état :** continuation après les KPI; pas de vrai avion identifié, carte Pro historique.
- **Composition :** `Most flown aircraft Papercraft`, `All Aircraft Stats`, PRO `Complete Your Map & Stats`, `Past Flights` table header `Date / From / To / Airline / Aircraft`.
- **Interaction / transition :** All Aircraft Stats ouvre 147; row past flight ouvre le détail.
- **Via / Apple :** `Section`, `NavigationLink`, `ProBenefitCard`, table/list adaptative.

### Capture 134 — aircraft summary

- **But / état :** `Most flown aircraft B737-9`, 5 flights; past flights commence.
- **Composition :** Passport header, stats aircraft avec badge/illustration, PRO card, premières rows historiques.
- **Interaction / transition :** tap aircraft ouvre stats; tap past flight ouvre détail.
- **Via / Apple :** `AircraftSummaryCard`, `List`, `NavigationStack`.

### Capture 135 — past flights, liste dense

- **But / état :** table `2026 — 27 FLIGHTS` avec routes et dates.
- **Composition :** rows denses mais lisibles, date à gauche, From/To au centre, airline/aircraft en trailing; map/Passport header persiste.
- **Interaction / transition :** scroll et tap row; filtres All-Time/2026 restent en haut.
- **Via / Apple :** `List` ou `LazyVStack`, `monospacedDigit` pour dates/chiffres.

### Capture 136 — passeport visuel

- **But / état :** représentation partageable `Flighty Passport` type document/passeport.
- **Composition :** carte claire sur fond map, header `ALL-TIME`, `MY FLIGHTY PASSPORT`, numéros, membre/authority/date et bande MRZ-like; boutons share.
- **Interaction / transition :** Share exporte une image/card; retour vers stats.
- **Via / Apple :** composant illustration custom, `ShareLink`/`ImageRenderer`; label d’accessibilité décrivant les KPI.

### Capture 137 — Flight stats: vols et distance

- **But / état :** `Flights` et `Flight Distance` pour All-Time 2026.
- **Composition :** header `Flighty Passport`, filtres période, cartes/graphes `27`, `10 domestic`, `17 international`, `11 long haul`, distance km/mi et moyenne.
- **Interaction / transition :** Share natif; scroll vers Flight Time.
- **Via / Apple :** `Chart`/metrics custom accessibles, `ShareLink`, `Picker` période.

### Capture 138 — distance, plus court et plus long

- **But / état :** distance avec `Shortest flight Dallas → Dallas 0 km`, `Longest flight San Francisco → Dubai 13 020 km`, début Flight Time.
- **Composition :** KPI, deux grandes cartes route, unités km/mi, labels explicatifs.
- **Interaction / transition :** tap route ouvre le flight detail; Share exporte la section.
- **Via / Apple :** `NavigationLink`/`Button`, `MetricCard`, chiffres tabulaires.

### Capture 139 — flight time

- **But / état :** distribution/metrics de durée, plus court/long, top visited airports en dessous.
- **Composition :** graphe de durée, grandes valeurs `6h16`, `145h55`, cards shortest/longest, header `Flight Time` et `Share`.
- **Interaction / transition :** Show More/scroll vers aéroports; share section.
- **Via / Apple :** `Chart` avec résumé vocal, `ScrollView`, `ShareLink`.

### Capture 140 — top visited airports

- **But / état :** `21 total airports`, règle des connexions <8h, classement SFO/DFW/LAX et autres; top airlines commence.
- **Composition :** rows classées avec compte, codes; section suivante avec logos/compagnies et stats distance.
- **Interaction / transition :** tap aéroport ouvre détail; Share.
- **Via / Apple :** `List`/`Section`, `NavigationLink`, badges/avatars custom.

### Capture 141 — top airlines et top routes

- **But / état :** `14 total airlines`, classement par vols/distance puis `27 total routes`.
- **Composition :** deux sections, logos/code, nombres; top route `AKL–SFO` visible et actions Share.
- **Interaction / transition :** tap compagnie/route; scroll.
- **Via / Apple :** rows composables, `NavigationLink`, `ShareLink`.

### Capture 142 — pays et territoires

- **But / état :** répartition géographique: US, South Africa, Australia, Asia/Europe/N. America/Oceania/Middle East/S. America/Africa.
- **Composition :** header `Countries & Territories`, pourcentages, liste/mini-chart par région, Share.
- **Interaction / transition :** tap pays ouvre les vols; aucune interaction sur le diagramme si non utile.
- **Via / Apple :** `Chart`/`LazyVStack`, `accessibilityChartDescriptor`, `NavigationLink`.

### Capture 143 — Delay Report global

- **But / état :** `52% My flights delayed`, 14/27 vols arrivés en retard; cartes Lost to Delays, Worst Delay, Worst Airline.
- **Composition :** header `Flighty All-Time Delay Report`, grands pourcentages/temps `10h`, compagnie Qantas; couleurs rouge/orange discrètes.
- **Interaction / transition :** scroll vers performance; Share.
- **Via / Apple :** `StatsSummaryCard`, `NavigationStack`, `ShareLink`, text + color.

### Capture 144 — performance personnelle

- **But / état :** distribution cumulative: Early 37%, On Time 30%, 15m/30m/45m late, canceled/diverted; airline performance.
- **Composition :** graphe/segments, légende, section airlines `Air China`, `Air Canada`, etc.; Share dans header.
- **Interaction / transition :** Show More compagnies; tap ouvre historique filtré.
- **Via / Apple :** `Chart` accessible, `List`/`Section`, `NavigationLink`.

### Capture 145 — performance airlines et airports

- **But / état :** `52% late arrivals` par compagnie et `63% late departures` par aéroport.
- **Composition :** deux sections rankées, rows `100% (2/2)` et bouton `Show More`; header Delay Report.
- **Interaction / transition :** tap row filtre les vols; Show More ouvre liste complète.
- **Via / Apple :** `List`, `Button`, `NavigationLink`; ratios annoncés en texte.

### Capture 146 — détails des retards

- **But / état :** listes `Departure Delays` par route et `Arrival Delays` par vol/compagnie avec dates.
- **Composition :** sections à deux colonnes/rows, pourcentage, compteur, codes SFO–DFW etc.; Share.
- **Interaction / transition :** tap route/flight; scroll.
- **Via / Apple :** `LazyVStack`/`List`, composant `DelayRow` et `ShareLink`.

### Capture 147 — Aircraft Stats résumé

- **But / état :** `12 total aircraft`, plus récent 7 mois, plus ancien 27 ans, most flown `B737-800`.
- **Composition :** header Aircraft Stats, cards dates/ages, grand aircraft badge/illustration.
- **Interaction / transition :** sections `Aircraft Types`, `Class and Seat`, `Most Frequent Tails`, `Aircraft Age`.
- **Via / Apple :** `StatsHeader`, cards, `NavigationStack`; illustration custom non interactive.

### Capture 148 — types d’avion et classes

- **But / état :** liste de 12 types ICAO (`A21N`, `B789`, `B738`, `E75W`, `B772`, `B77W`, etc.) et début `Class and Seat`.
- **Composition :** rows avec flights/time/distance, `Show More`; section class top `Premium Economy`.
- **Interaction / transition :** tap type ouvre les vols; Share.
- **Via / Apple :** `List`, `NavigationLink`, `ShareLink`; tableaux accessibles.

### Capture 149 — classes et sièges

- **But / état :** distribution Economy/Premium Economy/Business/First et seat Aisle/Middle/Window.
- **Composition :** cartes pourcentages/nombres, `Premium Economy 9 · 69%`, `Window 6 · 100%`; header Share.
- **Interaction / transition :** scroll vers Reason/tails; tap éventuel filtrage.
- **Via / Apple :** `Chart`/`MetricCard`, légende textuelle; pas de pie chart seul sans description.

### Capture 150 — raisons et tails

- **But / état :** `Top Reason Personal 54%, Business 46%`, `Most Frequent Tails: None`.
- **Composition :** sections reason et empty `No repeat planes yet`; suite `Aircraft Age` visible.
- **Interaction / transition :** aucun CTA nécessaire pour empty tails; scroll.
- **Via / Apple :** `EmptyStateView` inline, `List`, color semantic.

### Capture 151 — age des avions

- **But / état :** median age 11 years, histogram décennie, newest 7 months, oldest 27 years.
- **Composition :** header `Aircraft Age`, bar chart 1990s–2020s, cards de dates/aircraft en bas.
- **Interaction / transition :** tap aircraft ouvre détail; Share.
- **Via / Apple :** `Chart` + `accessibilityChartDescriptor`, `NavigationLink`, Reduce Motion.

### Capture 152 — age avec avions extrêmes

- **But / état :** même histogramme avec exemples `E295 / ZS-BJW`, `B772 / N77006`.
- **Composition :** données extrêmes visibles sous les cards; alignement stable avec 151.
- **Interaction / transition :** tap exemple ouvre flight/aircraft; retour conserve la section.
- **Via / Apple :** composant `AircraftAgeCard` configurable; `Button`/`NavigationLink`.

### Capture 153 — Passport past flights par route

- **But / état :** table de vols passés avec aircraft badges (`A321`, `N974UY`) et routes.
- **Composition :** header Passport, `All-Time/2026`, rows datées; map/surface et tab bar persistent.
- **Interaction / transition :** tap row flight detail; scroll.
- **Via / Apple :** `List`/`LazyVStack`, `FlightTimelineRow`; labels de badge inclus dans VoiceOver.

### Capture 154 — past flights groupés par départ

- **But / état :** groupement par aéroport (`Auckland AKL`, `Beijing PEK`, `Cape Town CPT`, `Dallas DFW`) avec nombre de flights.
- **Composition :** sections alphabétiques, count `1 FLIGHT`/`2 FLIGHTS`, sous-rows destinations.
- **Interaction / transition :** tap section/row; expansion si nécessaire avec `DisclosureGroup` natif.
- **Via / Apple :** `List`, `Section`, `DisclosureGroup` au lieu d’un accordion custom.

### Capture 155 — Your All-Time Passport partageable

- **But / état :** document de passeport avec `View and Share`, nom/membre/autorité/date, KPI et code MRZ-like.
- **Composition :** sheet claire, carte passeport centrale, actions bottom `Blacklight`, `Messages`, `Photos`, `More`.
- **Interaction / transition :** View and Share ouvre le partage; More ouvre menu système; photos/messages restent actions natives.
- **Via / Apple :** `ShareLink`, `Menu`, `PhotosPicker`/Messages si implémentés; illustration custom.

### Capture 156 — passeport avec toolbar final

- **But / état :** même document après interaction, avec barre d’actions persistante.
- **Composition :** carte passport, KPI, MRZ-like, bottom action icons; tap targets >=44.
- **Interaction / transition :** partage/édition/close; aucune action ne repose sur une zone décorative.
- **Via / Apple :** `ShareLink`, `Menu`, `Button`, `NavigationStack`; accessible labels pour chaque icon-only button.

## 157–168 — profil, amis et préférences d’alertes

### Capture 157 — profil depuis le shell

- **But / état :** entrée du profil utilisateur depuis la navigation; le vol/route reste en arrière-plan.
- **Composition :** carte géographique, sheet basse avec actions `Add Your Name`, `Edit Profile`, `Manage Friends`; aperçu d’un vol San Francisco → Los Angeles.
- **Interaction / transition :** Edit Profile ouvre 158/159, Manage Friends ouvre 163; les actions sont des rows pleines.
- **Via / Apple :** `NavigationStack`, `List`/`Section`, `Button`; dans Via cette hiérarchie devient l’onglet `Moi` au lieu d’un bouton profil dans la sheet.

### Capture 158 — Edit Your Profile, état vide

- **But / état :** expliquer ce que les amis voient; nom/photo non configurés.
- **Fond / composition :** carte Bahamas/Cuba derrière une sheet blanche, titre `Edit Your Profile`, sous-texte long sur le profil partagé; zone avatar vide.
- **Interaction / transition :** tap avatar ouvre les options de capture 159; champ nom/édition accessible.
- **Via / Apple :** `NavigationStack`, `PhotosPicker`/`ImagePicker` via wrapper, `TextField`; surface Flighty custom.

### Capture 159 — choix de photo de profil

- **But / état :** action contextuelle `Take Photo`, `Open Photos`, `Fill From Contacts`.
- **Composition :** profil toujours sur carte; menu/sheet d’actions courtes avec icônes et label `Recommended`.
- **Interaction / transition :** chaque action ouvre permission/sélecteur Apple; dismiss annule.
- **Via / Apple :** `confirmationDialog`/`Menu`, `PhotosPicker`, `Contacts` et `AVCapture` seulement derrière adapters; aucun picker custom.

### Capture 160 — profil avec carte de voyages

- **But / état :** profil en cours d’édition, carte de vols/trips visible, texte explicatif.
- **Composition :** carte large, sheet `Edit Your Profile`, compteur `3 DAYS` et petits points/segments de trajet; avatar area.
- **Interaction / transition :** ajout photo/nom; la carte est illustrative et ne vole pas les taps.
- **Via / Apple :** `Map`/rendu de voyages réutilisé, `Button`/`PhotosPicker`; éléments décoratifs `.allowsHitTesting(false)`.

### Capture 161 — profil identifié

- **But / état :** nom `Alex Smith` renseigné.
- **Composition :** carte de voyages, header Edit Your Profile, avatar/nom en bas; sous-texte identique.
- **Interaction / transition :** Done/save revient au profil; tap avatar réouvre le picker.
- **Via / Apple :** `Form`/`TextField`, `NavigationStack`, `PhotosPicker`; nom dans le modèle Account.

### Capture 162 — shell My Flights avec vol

- **But / état :** retour au shell après profil; un vol `EI337 Berlin → Dublin` est visible.
- **Fond / composition :** carte Europe, sheet basse `My Flights`, row de vol et tab bar; l’onglet Friends/Passport reste accessible.
- **Interaction / transition :** tap vol ouvre le détail; navigation de profil est terminée.
- **Via / Apple :** map shell partagé et `TabView`; ne pas présenter le profil comme une sheet automatique à chaque retour.

### Capture 163 — liste Flighty Friends

- **But / état :** gestion des connexions, une relation `Sam Lee` existe.
- **Composition :** carte/blank sheet, titre `Flighty Friends`, texte explicatif sur partage, invitations et accès; row avatar/nom Sam.
- **Interaction / transition :** tap Sam ouvre `Manage Friend`; ajouter ami utilise `ShareLink`/invite; suppression dans le détail.
- **Via / Apple :** `NavigationStack`, `List`, `Button`/`NavigationLink`; social reste dans `Moi`.

### Capture 164 — Manage Friend, préférence d’alertes

- **But / état :** fiche Sam avec `Share My Flights` et `Customize Alerts`.
- **Composition :** header/back, nom Sam Lee; texte expliquant que les alertes personnalisées remplacent la préférence générale; carte PRO; choix `None`, `Just Landed`, `Basics`.
- **Interaction / transition :** tap une carte sélectionne; tap Customize Alerts ouvre 165; Share My Flights est un Toggle/row.
- **Via / Apple :** `Toggle`, `Picker`/état carte, `NavigationStack`; `ProBenefitCard` custom.

### Capture 165 — Manage Friend, toutes les options

- **But / état :** quatre choix (`None`, `Just Landed`, `Basics`, `Everything`) plus `New Flights` et `Remove Friend`.
- **Composition :** grandes cartes gris clair, icônes colorées; une sélection bleue; descriptions multi-lignes; Remove Friend en bas.
- **Interaction / transition :** selection persiste; New Flights toggle; Remove ouvre confirmation 167.
- **Via / Apple :** `Picker` visuellement custom ou rows Button avec `accessibilityAddTraits(.isSelected)`, `Toggle`, `confirmationDialog`.

### Capture 166 — Customize Alerts en vue initiale

- **But / état :** même parcours avec header `Share My Flights` et carte PRO avant la sélection détaillée.
- **Composition :** sheet blanche, sous-titre “This overrides your general Friends’ Flights Alert preference”; options None/Just Landed/Basics.
- **Interaction / transition :** tap option; back revient à Manage Friend; aucune barre custom.
- **Via / Apple :** `NavigationStack`, `Picker`/custom card, `Toggle`; conserver la sheet adaptative si présentée depuis la carte.

### Capture 167 — suppression d’un ami

- **But / état :** confirmation destructive `Remove This Friend?`; partage des deux côtés sera révoqué.
- **Composition :** alert/dialog au-dessus de Manage Friend, actions `Remove Friend` destructive et cancel; le texte annonce l’impact sur les alertes.
- **Interaction / transition :** destructive supprime la relation et revient à Friends; cancel laisse l’écran intact.
- **Via / Apple :** `confirmationDialog` ou `alert` avec role `.destructive`; jamais de suppression immédiate au tap.

### Capture 168 — Friends vide / sortie du détail

- **But / état :** écran de retour sans relation affichée, état vide de Friends.
- **Composition :** carte/map et sheet minimale, titre Friends; aucun row de friend.
- **Interaction / transition :** Add Friend/Search depuis l’empty state; retour à l’onglet précédent.
- **Via / Apple :** `EmptyStateView`, `TabView`, `Button`; état Account observable.

## 169–182 — Settings, Pro et alertes

### Capture 169 — Settings, index

- **But / état :** page racine de réglages.
- **Composition :** `Settings` en grande navigation blanche; sections `Flighty Pro`, `Alerts` (`My Flights`, `Friends’ Flights`), `Automations` (`Calendar Sync`, `TripIt Sync`, `Add Flights via Email`), puis Extensions.
- **Interaction / transition :** chaque row push une destination; aucun multi-menu nécessaire.
- **Via / Apple :** `NavigationStack`, `List`, `Section`, `NavigationLink`; c’est le modèle à reprendre dans l’onglet `Moi`.

### Capture 170 — Settings extensions et customize

- **But / état :** suite de la liste settings.
- **Composition :** sections `EXTENSIONS` (`Live Activities`, `Lock Screen Widgets`, `Home Screen Widgets`, `Apple Watch`), `CUSTOMIZE` (`App icon`, `Units`), `MANAGE` (`Import Flights`, `Account Data`).
- **Interaction / transition :** rows push settings spécialisés; valeurs trailing éventuelles.
- **Via / Apple :** `List`, `Section`, `NavigationLink`, `Picker`/`Menu` dans les écrans enfants.

### Capture 171 — Settings aide et About

- **But / état :** bas de Settings.
- **Composition :** rows Account Data, `HELP CENTER` (`FAQ`, `Send Feedback`, `What’s New`, `Give Free Flights to Friends`, `Join Flighty Insiders`), `About`; tagline finale.
- **Interaction / transition :** FAQ ouvre un index, feedback ouvre mail/form, About ouvre 227.
- **Via / Apple :** `List`, `Link`/`Button`, `openURL`, `NavigationStack`; textes de confidentialité visibles.

### Capture 172 — Flighty Pro, plans

- **But / état :** paywall initial avec bénéfices `Late Aircraft Alerts`, `Exclusive Delay Predictions`, vol preview SFO → New York.
- **Composition :** sheet/route blanche, titre `Flighty PRO`, carte preview de vol, plan `BEST VALUE Unlimited Annual $7.49/month SAVE 75%`.
- **Interaction / transition :** choix plan via `Picker`/buttons, achat système StoreKit; close/back.
- **Via / Apple :** surface/marketing custom, `Button`, StoreKit adapter; aucun faux tab/picker système remplacé sans raison.

### Capture 173 — Pro live weather radar

- **But / état :** bénéfice Pro `Live Weather Radar — See what’s coming`, option Family Plans.
- **Composition :** écran très visuel, carte météo/radar en fond, header Pro et CTA; grande lisibilité plutôt que liste dense.
- **Interaction / transition :** Show Family Plans ouvre plan; close revient aux settings.
- **Via / Apple :** `NavigationStack`/sheet, `Button`, `ShareLink` non requis; motion/radar réduit sous Reduce Motion.

### Capture 174 — Pro Live Activities

- **But / état :** bénéfice `Live Activities`, preview Dynamic Island/Lock Screen avec `AA1001 SFO → JFK`, gate arrival.
- **Composition :** large preview noire/blanche, statut `On Time`, durée; carte plan `Annual Family $179.98 billed annually`.
- **Interaction / transition :** sélectionner plan/restore; preview n’est pas interactive si elle ne l’est pas.
- **Via / Apple :** ActivityKit/WidgetKit pour le produit réel, preview custom uniquement marketing; `Button` natif.

### Capture 175 — Pro, preuve sociale

- **But / état :** page de bénéfices et avis, `Editors’ Choice`, note 4.8, 165,000 ratings.
- **Composition :** header Pro, texte marketing, badge Editors’ Choice, cards de testimonials; scroll vertical.
- **Interaction / transition :** `Read`/links éventuels, purchase CTA; aucun contrôle caché dans l’avis.
- **Via / Apple :** `ScrollView`, `Link`, `Button`; cards custom, Dynamic Type.

### Capture 176 — témoignages Pro

- **But / état :** suite de témoignages utilisateurs.
- **Composition :** plusieurs grandes citations dans des cards/blocs, hiérarchie secondaire, header Pro et scroll.
- **Interaction / transition :** scroll; back/close vers plans.
- **Via / Apple :** `LazyVStack`, textes accessibles; ne pas auto-animer les citations.

### Capture 177 — top features Pro

- **But / état :** liste des fonctions incluses: Where’s My Plane, Flight Alerts, Live Activities, Assistants, Automations.
- **Composition :** titre `FEATURES ON BOARD`, rows/icônes, badge exclusive, explications courtes et mention “Not included in Pay-As-You-Go”.
- **Interaction / transition :** tap feature peut ouvrir un détail; CTA plan reste disponible.
- **Via / Apple :** `List`/`Section`, `Button`/`NavigationLink`, badges custom.

### Capture 178 — fin de Pro, legal et restauration

- **But / état :** conclusion paywall, identité produit/équipe et liens légaux.
- **Composition :** tagline “For flyers. By flight nerds.”, Austin/Barcelona/Oslo, privacy/self-funded, actions `Back to plans`, `Restore Purchase`, `Privacy Policy`, `Terms of Service`.
- **Interaction / transition :** restore StoreKit; links `Link`; retour plans.
- **Via / Apple :** `NavigationStack`, `Link`, `Button`, StoreKit adapter; texte légal natif/accessible.

### Capture 179 — My Flight Alerts, catégories

- **But / état :** choix global des notifications pour les vols de l’utilisateur.
- **Composition :** header/back `My Flight Alerts`, sous-titre; cartes `Basics`, `Above & Beyond`, `Flight Plans`, `Arrival Information` avec icône, résumé et contrôle sélection.
- **Interaction / transition :** tap une catégorie ouvre/active un groupe; Pro lock éventuel; retour settings.
- **Via / Apple :** `List`/`Section`, `Toggle`/`Picker`, cards custom seulement pour la surface.

### Capture 180 — My Flight Alerts avec contenu détaillé

- **But / état :** même écran avec texte plus visible et états de contrôle.
- **Composition :** cards verticales, marges constantes, couleurs d’icônes par type; les alertes critiques précèdent les enrichissements Pro.
- **Interaction / transition :** sélection indépendante; la préférence est persistée localement/remote.
- **Via / Apple :** `Toggle`, `NavigationLink`, `Menu` pour le détail; tester VoiceOver sur chaque carte.

### Capture 181 — Friends’ Flight Alerts, référence principale

- **But / état :** choix par défaut des notifications d’amis, aucune alerte sélectionnée ou état initial.
- **Fond / sheet :** carte monde visible derrière une grande sheet blanche presque pleine hauteur, coins supérieurs très arrondis, marge horizontale ≈32–40 px et safe area basse respectée.
- **Contenu / actions :** titre large `Friends’ Flight Alerts`, sous-titre explicatif, carte PRO lavande avec pill `PRO` et chevron; quatre cartes `None`, `Just Landed`, `Basics`, `Everything` avec icônes rouge/verte/bleue/violette et descriptions; note Live Activities en bas.
- **Via / Apple :** `NavigationStack`/`sheet` existant + cartes custom; selection par `Picker`/buttons et `accessibilityAddTraits(.isSelected)`, pas de tab/menus dessinés.

### Capture 182 — Friends’ Flight Alerts, variante de sélection

- **But / état :** même préférence affichée après un changement/scroll; toutes les options restent disponibles.
- **Fond / géométrie :** même map + sheet, même grande marge; l’outline bleu autour de l’option sélectionnée est la seule variation forte.
- **Interaction / transition :** tap une carte déplace la sélection sans changer la hauteur; lien Settings > Live Activities reste un parcours séparé.
- **Via / Apple :** `Picker` customisé visuellement ou rows `Button`; modèle `FriendAlertPreference`, test de persistance et Reduce Motion.

## 183–219 — synchronisation, import, données et aide

### Capture 183 — Calendar Sync Pro lock

- **But / état :** réglage calendrier non activé, bénéfice Pro requis.
- **Composition :** header `Calendar Sync`, carte `PRO Upgrade to sync your calendar`, texte import/export, rows `Import Flights / Choose Calendars`, `Export Flights / Choose Calendar`, note de confidentialité on-device.
- **Interaction / transition :** upgrade StoreKit; choose calendars demande EventKit; import/export déclenche permissions natives.
- **Via / Apple :** `NavigationStack`, `List`, `Button`, EventKit adapter, Pro card custom.

### Capture 184 — Calendar Sync autorisé, sélection

- **But / état :** complimentary Pro, limite historique 1 an; rows ont `Select`.
- **Composition :** header, badge PRO, texte sync, `Import Flights / Choose Calendars Select`, `Export Flights / Choose Calendar Select`, privacy.
- **Interaction / transition :** Select ouvre le sélecteur Apple; choix met à jour le label trailing.
- **Via / Apple :** EventKit native; `NavigationLink`/sheet, `Picker` si choix interne.

### Capture 185 — calendriers sauvegardés

- **But / état :** `Saved Calendars`, Work choisi, `Sync Deletions Off`.
- **Composition :** rows Import/Export, section saved, toggle sync deletions, notice; surface list native.
- **Interaction / transition :** toggle met à jour la politique; les calendriers se désélectionnent via système.
- **Via / Apple :** `Toggle`, EventKit, `List`; ne pas coder un switch custom.

### Capture 186 — sync Work

- **But / état :** calendrier `Work` choisi et sync active; suppression des événements encore Off.
- **Composition :** mêmes sections, valeurs trailing; texte explique import/export et privacy.
- **Interaction / transition :** change toggle ou choose calendar; back.
- **Via / Apple :** `Toggle`, `Button`/`NavigationLink`, repository settings injectable.

### Capture 187 — confirmation Sync Deletions Off

- **But / état :** explication détaillée de la politique de suppression; `Off (Recommended)`.
- **Composition :** callout texte long, options On/Off, calendrier Work et sections import/export.
- **Interaction / transition :** sélectionner On peut demander confirmation; Off recommandé reste explicite.
- **Via / Apple :** `Picker`/`Toggle`, `confirmationDialog` si risque destructif; Dynamic Type critique.

### Capture 188 — Sync Deletions On

- **But / état :** même page, `Sync Deletions On` confirmé.
- **Composition :** valeur On visible dans la row; copy privacy et import/export inchangée.
- **Interaction / transition :** retour persiste; suppression réelle dépend du service de synchronisation.
- **Via / Apple :** `Toggle`/`confirmationDialog`, test d’impact et état error/offline.

### Capture 189 — TripIt Sync

- **But / état :** connexion TripIt non configurée.
- **Composition :** header/back, carte PRO `Upgrade to sync with TripIt`, explication past/future flights, CTA `Connect TripIt Account`, setup tips (ad blockers, Safari, wait 5 seconds), privacy zero data.
- **Interaction / transition :** Connect ouvre auth/web flow; erreurs restent dans la page.
- **Via / Apple :** `Button`, `Link`/`SFSafariViewController` adapter, `NavigationStack`; pas de navigateur custom inutile.

### Capture 190 — Add Flights via Email non configuré

- **But / état :** import automatique par email verrouillé Pro.
- **Composition :** header, PRO upgrade card, texte forward confirmations, section `YOUR EMAIL ADDRESSES`, CTA `Get Started`, note de rétention data.
- **Interaction / transition :** Get Started ouvre add address 191; upgrade paywall.
- **Via / Apple :** `List`/`Section`, `NavigationLink`, `ProBenefitCard`, privacy text.

### Capture 191 — ajout d’adresse email

- **But / état :** `Add Email Address` lancé depuis la page email.
- **Composition :** sheet/navigated form très simple, header `Add Flights via Email`, champ/CTA et clavier éventuel.
- **Interaction / transition :** tap field → 192; cancel/back ne sauvegarde pas.
- **Via / Apple :** `TextField`, `FocusState`, `Button` Done, validation email.

### Capture 192 — email saisi

- **But / état :** adresse `nith.moebbin+1@gmail.com` saisie, clavier numérique/texte visible.
- **Composition :** form blanc, title/close, champ actif avec cursor; bouton confirm.
- **Interaction / transition :** validation envoie le mail de vérification; erreur inline près du champ.
- **Via / Apple :** `TextField` `.keyboardType(.emailAddress)`, `onSubmit`, `Button`; pas d’auto-focus non sollicité sur appareil tactile.

### Capture 193 — email à vérifier, limite Pro

- **But / état :** adresse ajoutée; `PRO Limit 3 emails`, `Check your inbox to verify`, `Check Your Email`.
- **Composition :** liste d’adresses avec ellipsis, instructions forward vers `track@my.flightyapp.com`, badge verification required, privacy.
- **Interaction / transition :** check email relance/ouvre Mail; add address ajoute si quota; delete via swipe/context.
- **Via / Apple :** `Button`, `Link(mail:)`, `contextMenu`/`swipeActions` pour secondaire, confirmation si suppression.

### Capture 194 — email vérifié

- **But / état :** adresse affichée sans l’état “check inbox”; même limite et instructions.
- **Composition :** row email vérifiée, CTA Add Email Address, texte de forwarding; layout stable entre 193/194.
- **Interaction / transition :** ajout/suppression; retour settings.
- **Via / Apple :** `List`, `Section`, `Button`, `contextMenu`, state `verified` explicite avec icône + texte.

### Capture 195 — Live Activities, état d’un vol

- **But / état :** page settings Live Activities avec preview `AA1001 SFO`, gate, inbound en route.
- **Composition :** header/back, grande preview type Lock Screen/Dynamic Island, texte sur lock screen/Dynamic Island/CarPlay/Watch/Mac, CTA `Show Friend’s Flights`.
- **Interaction / transition :** toggle/CTA friend; permissions ActivityKit suivent le système.
- **Via / Apple :** ActivityKit/WidgetKit et `Toggle` dans la page; preview custom non interactive.

### Capture 196 — Live Activities Pro

- **But / état :** même page avec badge PRO et CTA friend flights.
- **Composition :** preview sombre, texte marketing, action `Show Friend’s Flights`; map de fond possible.
- **Interaction / transition :** upgrade/setting; permission système.
- **Via / Apple :** ActivityKit, `NavigationStack`, `Button`, `Toggle`; preserve reduce motion in preview.

### Capture 197 — choix App Icon

- **But / état :** grille `CHOOSE YOUR APP ICON`: Normal, Nighty, Tracky, Boardy, Pridey.
- **Composition :** sheet blanche, titres/illustrations d’icônes, sous-titre descriptif (`awesome icon`, `Blink blink`, etc.).
- **Interaction / transition :** tap icon change l’icône; feedback système/confirmation; retour settings.
- **Via / Apple :** rows/buttons custom pour preview, `UIApplication.setAlternateIconName` via adapter; aucun grid gesture sans Button.

### Capture 198 — icône changée confirmation

- **But / état :** toast/banner “You have changed the icon for Flighty”, icon sélectionnée, bouton `OK`.
- **Composition :** même choix App Icon, overlay/alert confirmation courte.
- **Interaction / transition :** OK ferme; changement reste persisté.
- **Via / Apple :** `alert`/`confirmationDialog` ou feedback inline, `Button`; SF Symbols/preview custom.

### Capture 199 — App Icon sans confirmation

- **But / état :** retour à la grille avec choix courant visible.
- **Composition :** rows/tiles Normal, Nighty, Tracky, Boardy, Pridey; sélection accentuée sans déplacer le layout.
- **Interaction / transition :** tap icon; back.
- **Via / Apple :** `Button` tile avec `.isSelected`, alternate icon adapter.

### Capture 200 — Units initial

- **But / état :** préférences unités propres à l’appareil.
- **Composition :** header/back, explication; sections `Aircraft Speed` avec `mph / km/h / kt`, `Altitude` avec `ft / km / m / FL`; contrôles segmentés/radio.
- **Interaction / transition :** sélection immédiate, valeur persistée; device settings mentionnés pour le reste.
- **Via / Apple :** `Picker` `.segmented`/`Menu`, `List`/`Section`, pas de segmented control dessiné.

### Capture 201 — Units, variante de sélection

- **But / état :** même écran avec unités choisies/variation de focus.
- **Composition :** rows/segments et explication inchangés; selected state lisible.
- **Interaction / transition :** tap unité, retour settings; pas de confirmation si non destructive.
- **Via / Apple :** `Picker`, `@AppStorage`/model settings; Dynamic Type et VoiceOver annoncent la valeur.

### Capture 202 — vol en direct sur carte

- **But / état :** `WN3780 Orlando → San Juan`, landing in 9m, altitude/vitesse affichées sur la carte.
- **Fond / composition :** carte sombre océan Atlantique, route/avion au centre, overlay flight detail en bas avec MCO/SJU, terminal/gate.
- **Interaction / transition :** map pan/zoom natifs, tap detail; données live se mettent à jour sans flash.
- **Via / Apple :** `Map`/`MapCameraPosition`, annotations/route; valeurs vitesse/altitude issues des Units, sheet adaptative.

### Capture 203 — Import Flights services

- **But / état :** choisir un service d’import historique, Pro limitation 1 year.
- **Composition :** header/back `Import Flights`, texte; grille/liste services `Flighty`, `myFlightradar24`, `LogmyFlight`, `JetLovers`, `FlightMemory`.
- **Interaction / transition :** tap service ouvre 204; services sont des buttons.
- **Via / Apple :** `List`/`LazyVGrid`, `NavigationStack`, `Button`, Pro card/label.

### Capture 204 — Start Your Import, email vide

- **But / état :** formulaire d’import qui envoie un guide par email.
- **Composition :** sheet/route blanche `Flighty Start Your Import`, texte “Enter your email…”, note privacy; champ vide et CTA.
- **Interaction / transition :** focus champ → clavier; submit → 205.
- **Via / Apple :** `TextField` email, `FocusState`, `Button`, validation inline.

### Capture 205 — Start Your Import, email rempli

- **But / état :** email prérempli, prêt à envoyer.
- **Composition :** même page, adresse visible; clavier possiblement présent; privacy note.
- **Interaction / transition :** submit envoie et ouvre confirmation; error proche du champ.
- **Via / Apple :** `TextField`, `.onSubmit`, `ProgressView` pendant envoi; bouton disabled anti double-submit.

### Capture 206 — import envoyé

- **But / état :** service sélectionné marqué `Sent`, message “Check your email”.
- **Composition :** page Import Flights, ligne service avec état success, autres services encore disponibles, Pro copy.
- **Interaction / transition :** retour/close; réessai éventuel via bouton.
- **Via / Apple :** `Button`, `ProgressView`/success state, repository import injecté.

### Capture 207 — Account Data index

- **But / état :** gestion des données: export, delete flights, delete account.
- **Composition :** header/back, section `EXPORT` `Export Your Flights` avec privacy/Pro note; `DELETE FLIGHTS` (`All Flights`, `Flights Added in Last 24 Hrs`); `DANGER ZONE` `Delete Your Account`.
- **Interaction / transition :** export share/file; deletes ouvrent confirmation; account deletion auth/Apple.
- **Via / Apple :** `List`, `Section`, `ShareLink`/file exporter, `confirmationDialog`, Sign in with Apple adapter.

### Capture 208 — confirmation delete recent flights

- **But / état :** dialog “Delete Recent Flights?” avec scope devices et irréversibilité.
- **Composition :** Account Data derrière; dialog white système avec `Delete Recent Flights` destructive et `Cancel`.
- **Interaction / transition :** confirm lance suppression; cancel revient intact.
- **Via / Apple :** `confirmationDialog`/`alert`, role `.destructive`; tests du scope exact.

### Capture 209 — suppression en cours

- **But / état :** `Deleting Flights` avec `In Progress…`.
- **Composition :** Account Data, section danger, progress/status inline; actions de suppression désactivées.
- **Interaction / transition :** completion success/error; pas de double requête.
- **Via / Apple :** `ProgressView`, état async dans view model, `.disabled(isDeleting)`.

### Capture 210 — suppression terminée

- **But / état :** feedback `32 Flights Deleted`.
- **Composition :** Account Data restauré, message success proche de l’action, reste des sections intact.
- **Interaction / transition :** message temporaire ou inline; retry si partial failure.
- **Via / Apple :** `ContentUnavailableView`/status row custom, `sensoryFeedback` optionnel.

### Capture 211 — confirmation suppression du compte

- **But / état :** dialog “Delete Your Account”, avertissement tous appareils/données irréversibles.
- **Composition :** Account Data derrière, dialog avec `Delete All Account Data` destructive et `Cancel`.
- **Interaction / transition :** confirm → auth/processing 212; cancel aucun changement.
- **Via / Apple :** `confirmationDialog`, auth Apple avant suppression, texte accessible.

### Capture 212 — suppression compte en cours

- **But / état :** `Deleting Account`, traitement global.
- **Composition :** Account Data avec danger zone, progress/status et actions désactivées.
- **Interaction / transition :** succès close/logout ou erreur retry; empêcher dismiss destructif accidentel.
- **Via / Apple :** `ProgressView`, `interactiveDismissDisabled` pendant l’opération, task cancellable si possible.

### Capture 213 — suppression terminée / close app

- **But / état :** “Delete Flighty Everywhere”, instruction de fermer l’app pour finaliser.
- **Composition :** page blanche, texte de fin, bouton `Close App`; Account Data derrière mais non actionnable.
- **Interaction / transition :** close termine le parcours; aucune reconnexion automatique.
- **Via / Apple :** `Button`, auth/session reset; ne jamais forcer `exit(0)` comme comportement normal sans validation produit.

### Capture 214 — FAQ index

- **But / état :** centre d’aide avec recherche et catégories.
- **Composition :** header `FAQ`, champ `Search`, sections `Adding Flights`, `Top Questions`, `Subscription`; rows Email forwarding, TripIt, Bulk import, Manually input, Calendar Sync, Account sync, etc.
- **Interaction / transition :** Search filtre; tap question ouvre article.
- **Via / Apple :** `NavigationStack`, `.searchable`, `List`/`Section`, `NavigationLink`.

### Capture 215 — article FAQ Search

- **But / état :** article `Using Search`, explique la Search Tab, vols passés/actuels/futurs et formats de query.
- **Composition :** titre article, paragraphes, section `TOP TIPS` (`AA101`, dates, Friday), section `Past flight not found`.
- **Interaction / transition :** scroll; lien vers FAQ Top Questions; `Send a Message` plus bas.
- **Via / Apple :** `ScrollView`, `Text`/`Link`, `.searchable` au niveau FAQ, Dynamic Type.

### Capture 216 — article FAQ suite

- **But / état :** même article avec conseils, explication de l’ajout manuel et bouton `Send a Message`.
- **Composition :** long texte, codes/date examples, action d’aide finale.
- **Interaction / transition :** Send Message ouvre mail/form; back FAQ.
- **Via / Apple :** `ScrollView`, `Link`/`Button`, `openURL` mail; pas de web-only control si le contenu est natif.

### Capture 217 — Help Center / choix de problème

- **But / état :** page aide après Settings, catégories `Adding Flights`, `I need subscription help`, `I’ve spotted something wrong`, `I have an idea`.
- **Composition :** sheet/list blanche, rows à icônes, titre `Is anything wrong?`.
- **Interaction / transition :** tap catég. ouvre 218/219 ou feedback form.
- **Via / Apple :** `List`, `Section`, `NavigationLink`, `Button`.

### Capture 218 — Adding Flights help index

- **But / état :** catégorie d’aide pour ajouter un vol.
- **Composition :** header/back `Adding Flights`, section links Search, Email forwarding, TripIt, Bulk import, Manually input, Calendar Sync, `My question isn’t in the list`.
- **Interaction / transition :** chaque row article; question custom ouvre message.
- **Via / Apple :** `NavigationStack`, `List`, `NavigationLink`; search global éventuellement `.searchable`.

### Capture 219 — choix de client email

- **But / état :** question Email forwarding, choix `Apple Mail`, `Other`.
- **Composition :** page `Adding Flights`, sous-section `Choose Email Client`, rows avec logos/labels; “My question isn’t in the list”.
- **Interaction / transition :** Apple Mail ouvre instructions/deep link; Other ouvre message/FAQ.
- **Via / Apple :** `List`, `Button`, `openURL`; choix simple `Picker` si nécessaire.

## 220–228 — annonces, nouveautés et About

### Capture 220 — annonce nouvelle navigation

- **But / état :** changelog onboarding “New Navigation, Ways to Friend, and Liveries”.
- **Composition :** écran blanc/marketing, preview du nouveau shell avec tabs rapides `My Flights`, `Friends`, `Passport` et Search; carte de vol illustrative.
- **Interaction / transition :** scroll/close; annonce informe sans modifier la navigation durant la lecture.
- **Via / Apple :** dans Via, cette annonce explique le passage à `TabView` natif; preview custom, navigation réelle système.

### Capture 221 — annonce airport conditions

- **But / état :** section `Browse Live Airport Conditions Worldwide`, Pro feature.
- **Composition :** preview shell + titre `PRIOR UPDATE`, texte sur communications officielles; carte `PRO Know What Could Disrupt Your Flight`.
- **Interaction / transition :** scroll vers 222; upgrade CTA.
- **Via / Apple :** `ScrollView`, `ProBenefitCard`, `Button`; texte et map preview accessibles.

### Capture 222 — annonce airport delays forecast

- **But / état :** détail Pro: SFO lightning/high cancellations, de-icing, `Airport Delays Forecast`.
- **Composition :** cartes incident avec badges `PRO`, résumé IA et explication “why”; fond riche mais surface lisible.
- **Interaction / transition :** tap feature/upgrade; les badges incident reprennent `LineCondition`/status vocabulary.
- **Via / Apple :** cartes custom, `Button`, `Chart` si forecast; beam CTA possible avec Reduce Motion.

### Capture 223 — annonce disruption et friending

- **But / état :** suite de nouveauté avec `Airport Strike`, `Friending Flexibility`.
- **Composition :** stack de cards feature, labels PRO/major issues, texte court, scroll.
- **Interaction / transition :** tap section ouvre le détail ou plan; close/back.
- **Via / Apple :** `ScrollView`, `NavigationLink`/`Button`, badges custom; pas de gesture pour la navigation.

### Capture 224 — 150 new liveries

- **But / état :** annonce visuelle de 150 nouvelles livrées d’avions.
- **Composition :** titre `Friending Flexibility` puis `150 New Liveries`, description des compagnies/tails, grande mosaïque d’illustrations d’avions.
- **Interaction / transition :** scroll vers 225; images décoratives non interactives sauf CTA explicite.
- **Via / Apple :** `ScrollView`, `LazyVGrid`, images rendues; `accessibilityLabel` groupé pour les visuels.

### Capture 225 — fin liveries et upgrade

- **But / état :** fin de l’annonce, CTA “Unlock these new features. And a whole lot more. Upgrade to Flighty Pro”.
- **Composition :** longue mosaïque/illustrations, grande carte CTA en bas.
- **Interaction / transition :** upgrade ouvre StoreKit paywall; partage/close si présents.
- **Via / Apple :** `Button`, `ScrollView`, `ProBenefitCard`; ne pas animer lourdement une mosaïque sous Reduce Motion.

### Capture 226 — actions de l’annonce

- **But / état :** même fin avec actions `Upgrade to Flighty Pro`, `Share with Friends`, `Rate in App Store`.
- **Composition :** footer d’actions verticales, priorisation Pro puis partage puis rating.
- **Interaction / transition :** ShareLink; StoreKit; `SKStoreReviewController` via adapter.
- **Via / Apple :** `ShareLink`, `Button`, `Link`/StoreKit, `NavigationStack`.

### Capture 227 — About

- **But / état :** page About avec liens sociaux/legal.
- **Composition :** header/back `About`, rows `Follow` Twitter/X/Instagram, `Team`, `Terms of Service`, `Privacy Policy`, `Licences`, `Data Providers`.
- **Interaction / transition :** Link ouvre URL; Team → 228; back settings.
- **Via / Apple :** `List`, `Section`, `Link`, `NavigationLink`, `openURL`.

### Capture 228 — Team

- **But / état :** présentation de l’équipe et mission.
- **Composition :** header `Team`, paragraphe sur les flight nerds et business durable, rows nom/rôle (`Engineering`, `Design`, `Product`).
- **Interaction / transition :** back About; profils non actionnables si aucun lien.
- **Via / Apple :** `List`/`ScrollView`, `Text`, `NavigationStack`; labels d’accessibilité normaux.

## 229–236 — Live Activities et widgets

### Capture 229 — Live Activity vide / placeholder

- **But / état :** capture de transition ou de preview sans contenu textuel détectable.
- **Composition :** fond majoritairement uni/sombre avec branding Flighty en bas; aucun contrôle applicatif stable.
- **Interaction / transition :** état système avant rendu de l’activité; ne pas traiter comme une page navigable.
- **Via / Apple :** WidgetKit/ActivityKit preview ou launch transition; pas de composant shell Via à déduire.

### Capture 230 — preview système de l’activité

- **But / état :** autre variante de preview Live Activity sans données lisibles.
- **Composition :** surface sombre/branding, safe area système; le contenu est géré par la configuration de widget.
- **Interaction / transition :** mise à jour vers 231–235; aucun tap custom hors intents/widgets.
- **Via / Apple :** `ActivityConfiguration`, `DynamicIsland`, widget preview; respecter les contraintes système.

### Capture 231 — Live Activity compacte, départ/arrivée

- **But / état :** compact presentation `AA6294`, `SFO → LAX`, Terminal 1.
- **Composition :** capsule/lock-screen native noire, logo Flighty, code vol, codes aéroport, gate/terminal; densité élevée et contraste fort.
- **Interaction / transition :** tap ouvre le flight detail via deep link; l’activité est rendue par le système.
- **Via / Apple :** ActivityKit/WidgetKit, `Link`/deep link; aucune capsule à dessiner dans l’app principale.

### Capture 232 — Live Activity avec compte à rebours

- **But / état :** activité `AA6294 SFO`, texte `UNTIL GATE ARRIVAL`.
- **Composition :** vue compacte avec code/airport et timer; typographie tabulaire, fond système sombre.
- **Interaction / transition :** timer évolue; suspendre/mettre à jour via ActivityKit; tap deep link.
- **Via / Apple :** `Text(timerInterval:)`/ActivityKit; Reduce Motion et accessibilité système.

### Capture 233 — statut On Time

- **But / état :** activité `AA6294`, terminal `T1`, status `On Time`.
- **Composition :** compact/expanded native, status text + éventuellement pastille accent; branding Flighty discret.
- **Interaction / transition :** update status; tap ouvre detail.
- **Via / Apple :** ActivityKit state model; red/green + texte, pas de statut couleur-only.

### Capture 234 — compte à rebours SFO

- **But / état :** variante timer `UNTIL GATE ARRIVAL` pour le même vol.
- **Composition :** airport SFO, timer dominant, safe area système et layout compact.
- **Interaction / transition :** timer et état ActivityKit; deep link.
- **Via / Apple :** WidgetKit/ActivityKit; tests snapshot de timeline.

### Capture 235 — activité d’un autre vol

- **But / état :** `WN3780 MCO → SJU`, `Terminal B · Gate B7`.
- **Composition :** compact/expanded black system surface, code, airports, terminal/gate; valeurs alignées.
- **Interaction / transition :** tap flight; updates de gate/landing.
- **Via / Apple :** configuration générique de Live Activity alimentée par `FlightActivityAttributes`; pas de nouvelle vue par compagnie.

### Capture 236 — widget trajet à deux jours

- **But / état :** widget Home Screen avec destination `Los Angeles`, échéance `2 Days`.
- **Composition :** widget système, fond carte/illustration, grand titre destination et compteur; aucune tab bar.
- **Interaction / transition :** tap widget deep link vers le détail ou l’onglet pertinent; timeline widget met à jour le compteur.
- **Via / Apple :** WidgetKit `TimelineProvider`/`AppIntentConfiguration`; ne pas réutiliser la TabView dans le widget.

## R1–R2 — captures fournies par l’utilisateur

### Capture R1 — champ tokenisé `[SFO] [lax|]`

- **But / état :** recherche d’une destination après origine sélectionnée; l’utilisateur tape `lax`.
- **Fond / composition :** surface claire quasi blanche; texte d’aide gris en haut; deux zones horizontales: token compact gris clair `SFO` à gauche et champ gris clair extensible à droite; rayon très généreux, marges latérales constantes.
- **Champ / contrôles :** `lax` noir, curseur bleu immédiatement après `x`, clear button circulaire gris avec `x` blanc à droite; le clavier système est implicite. Le token n’est pas un TextField actif mais doit rester supprimable/éditable par Button.
- **Réutilisation / Apple :** `SearchTokenField` avec `@FocusState`, `TextField`, `Button` clear, `accessibilityValue` “Origine SFO, destination lax en cours”; aucun dessin de curseur ni de clavier.

### Capture R2 — Friends’ Flight Alerts avec carte PRO

- **But / état :** choix par défaut des notifications reçues sur les vols d’amis; la capture montre l’écran de référence à grande hauteur.
- **Fond / sheet :** carte satellite/monde visible derrière, grande sheet blanche presque pleine hauteur, top corners très arrondis, bouton retour circulaire en haut à gauche, contenu sur une marge horizontale stable et footer/safe area respecté.
- **Hiérarchie / cartes :** titre noir très grand `Friends’ Flight Alerts`; description en deux lignes; carte PRO à contour lavande, pill `PRO`, texte violet “Alerts for picking up friends, monitoring loved ones, and more…” et chevron. Quatre cards gris très pâle, radius généreux: `None` rouge barré, `Just Landed` vert, `Basics` bleu, `Everything` violet; chaque description est grise et multi-ligne.
- **Interaction / réutilisation / Apple :** une carte sélectionnée reçoit un contour bleu épais sans changement de poids typographique; le lien Live Activities est secondaire en bas. Implémenter `FriendAlertOptionCard` via `Button`/`Picker`, `accessibilityAddTraits(.isSelected)`, `NavigationStack` + adaptive sheet; le badge PRO et le beam éventuel restent custom.
