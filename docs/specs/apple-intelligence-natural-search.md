# Recherche de trajet avec Apple Intelligence — V1

## Expérience

- Deux accès ouvrent la même feuille : un bouton IA dans le formulaire de recherche et un bouton dans sa toolbar.
- La première ouverture affiche une carte tutorielle unique inspirée de la référence Flighty. Les ouvertures suivantes affichent directement la saisie.
- La feuille commence à hauteur moyenne et passe en grande hauteur lorsque le clavier apparaît.
- La saisie accepte une phrase française et la dictée native du clavier. Ce n’est pas un chat et Via n’ajoute pas de bouton microphone.
- Trois exemples génériques enseignent les formulations prises en charge.

## Compréhension et résultats

- Foundation Models extrait localement origine, destination, date, départ/arrivée, heure et modes obligatoires, préférés ou exclus.
- Via recherche jusqu’à quatre itinéraires réels et conserve le classement déterministe du moteur.
- Aucun texte de réponse n’est généré.
- Les critères compris apparaissent comme des chips modifiables. Une modification relance la recherche.
- L’origine manquante propose la position actuelle ; un lieu ambigu présente au plus cinq choix.
- Une date et une heure absentes signifient maintenant. Une date explicite sans heure demande l’heure.
- Une heure passée sans date explicite passe au lendemain. Une date explicite passée demande une correction.
- Une contradiction de modes ou deux contraintes horaires demandent laquelle conserver.
- Une contrainte non supportée n’est jamais ignorée ; Via propose de continuer sans elle ou de modifier la demande.

## Disponibilité, confidentialité et erreurs

- Disponible en français : accès actifs.
- Appareil compatible mais Apple Intelligence désactivée ou modèle non prêt : accès visible et explication.
- Appareil non éligible ou français non supporté : accès masqués.
- Aucun fallback LLM serveur et aucun historique de phrases.
- En cas d’erreur, Via conserve la phrase et propose Réessayer ou Recherche classique.
- En cas d’absence de réseau après interprétation, Via conserve les critères et explique que les horaires nécessitent une connexion.
- Siri et App Intents sont hors V1.

## Validation

- Activation générale après réussite d’un corpus minimal de 100 formulations françaises.
- Objectif : 95 % d’extraction exacte sur les demandes non ambiguës, 100 % de clarification des champs critiques manquants, zéro horaire ou trajet inventé.
- Télémétrie sans phrase, lieu ou itinéraire : durée, résultat, nombre de corrections et temps jusqu’au premier résultat seulement.
- Aucun nouveau fichier de la fonctionnalité ne commence par `Via` ou `via`.
