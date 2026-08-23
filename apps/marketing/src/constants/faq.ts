import type { FAQContent } from "./types";

export const frequentlyAskedQuestions = [
  {
    question: "À quoi sert Metyro ?",
    answer:
      "Metyro réunit vos stations, vos itinéraires, les prochains passages et les perturbations dans une seule app. Vous retrouvez ainsi l’essentiel de vos trajets en Île-de-France, au même endroit.",
  },
  {
    question: "Les horaires sont-ils affichés en temps réel ?",
    answer:
      "Oui, lorsque les données en direct sont disponibles. Metyro distingue les horaires estimés en temps réel des horaires théoriques et indique la fraîcheur des informations affichées.",
  },
  {
    question: "Puis-je rechercher un trajet avec mes propres mots ?",
    answer:
      "Oui. Avec Apple Intelligence, vous pouvez écrire une demande comme « Gare de Lyon avant 18 h ». Metyro comprend le lieu, l’heure et vos préférences pour préparer l’itinéraire.",
  },
  {
    question: "Metyro propose-t-elle des itinéraires accessibles ?",
    answer:
      "Oui. Vous pouvez demander un itinéraire adapté aux personnes en fauteuil roulant et consulter les informations d’accessibilité disponibles pour les stations. Certaines pannes d’ascenseur peuvent toutefois ne pas être connues en temps réel.",
  },
  {
    question: "Où Metyro est-elle disponible ?",
    answer:
      "Metyro couvre actuellement les transports d’Île-de-France. L’app a vocation à accompagner prochainement vos trajets dans d’autres villes.",
  },
] as const satisfies readonly FAQContent[];
