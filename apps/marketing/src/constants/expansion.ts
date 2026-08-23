export const expansionContent = {
  eyebrow: "Couverture",
  title: "L’Île-de-France aujourd’hui. La vôtre ensuite.",
  description:
    "Metyro couvre le réseau francilien. La prochaine ville, c’est vous qui la choisissez : touchez un point sur la carte.",
  served: {
    region: "Île-de-France",
    status: "En service",
  },
  leaderboard: {
    title: "Les villes les plus demandées",
    empty: "Aucune ville n’a encore de voix. La première est à vous.",
    unavailable:
      "Le décompte est indisponible pour le moment. La carte, elle, reste ouverte.",
    total: (votes: number) =>
      votes === 1 ? "1 voix au total" : `${formatVotes(votes)} voix au total`,
  },
  card: {
    /*
     * The count is read as a number first and a sentence second, so it is
     * written that way too: the numeral stands alone at the top of the card and
     * the phrase underneath only has to agree with it.
     */
    count: (votes: number) => formatVotes(votes),
    demand: (votes: number) =>
      votes === 1 ? "personne la demande" : "personnes la demandent",
    none: "Personne ne l’a encore demandée",
    rank: (rank: number) =>
      rank === 1 ? "La plus demandée" : `${rank}ᵉ au classement`,
    action: "Je veux Metyro ici",
    voted: "Votre voix est comptée",
    failed: "Le vote n’a pas pu être enregistré. Réessayez.",
    close: "Fermer",
  },
  dot: (city: string, votes: number) =>
    votes === 0
      ? `${city} — aucune voix. Demander Metyro ici.`
      : `${city} — ${formatVotes(votes)} voix. Demander Metyro ici.`,
} as const;

function formatVotes(votes: number): string {
  return votes.toLocaleString("fr-FR");
}
