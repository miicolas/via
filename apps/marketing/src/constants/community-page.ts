export const communityContent = {
  metadata: {
    title: "Communauté",
    description:
      "Les systèmes savent qu’un train est en retard. Un voyageur sait que la sortie est mal indiquée. La communauté Metyro transforme ces détails vécus en meilleure information pour tout le monde.",
  },
  hero: {
    badge: "La communauté Metyro",
    headline: {
      line1: "Le réseau parle en données,",
      line2: "le terrain répond en",
      accent: "détails",
    },
    description:
      "Les systèmes savent qu’un train est en retard. Vous savez que la sortie est mal indiquée, que l’ascenseur est condamné ou que le message ne répond pas à la vraie question.",
    primaryAction: { label: "Participer", href: "#participer" },
    secondaryAction: { label: "Lire le journal", href: "/blog" },
  },
  blurHeadline:
    "Pas besoin d’être expert du métro. Il suffit d’avoir vécu le trajet. Une observation précise, faite au bon endroit, peut améliorer l’information de milliers de déplacements dès le lendemain.",
  participation: {
    eyebrow: "Participer",
    title: "Le meilleur capteur du réseau, c’est vous",
    description:
      "La communauté n’est pas un forum de plus. C’est l’endroit où un détail vécu devient une meilleure information pour tout le monde.",
    report: {
      title: "Racontez le moment, pas seulement le problème.",
      hint: "Où étiez-vous ? Qu’essayiez-vous de faire ? Quelle information manquait ? Le contexte transforme une frustration en piste d’amélioration.",
      visual: {
        meta: "Signalement · 08:17 · République",
        quote:
          "« La sortie 3 indique Rue du Temple. Elle est fermée depuis lundi. »",
        status: "Transmis à l’équipe produit",
      },
      action: { label: "Trouver le bon contact", href: "/help" },
    },
    fieldCheck: {
      title: "Confrontez l’écran à la vraie station.",
      hint: "Plans, libellés et alertes sont relus avec celles et ceux qui les utilisent dans le bruit et la foule.",
      visual: {
        rows: [
          { label: "Plan des sorties", status: "Validé sur place", done: true },
          { label: "Libellé d’alerte", status: "En relecture", done: false },
          { label: "Pictos d’accès", status: "Validé sur place", done: true },
        ],
      },
    },
    api: {
      title: "Détournez l’API vers un usage inattendu.",
      hint: "Une installation, un outil d’accessibilité, une expérience locale : montrez-nous ce que les mêmes données peuvent devenir.",
      action: { label: "Explorer l’API", href: "/api" },
    },
    expansion: {
      title: "Amenez Metyro dans votre ville.",
      hint: "La carte de couverture se dessine avec vos votes, une ville à la fois.",
      visual: {
        unit: "demande relative",
        rows: [
          { city: "Lyon", strength: 92 },
          { city: "Marseille", strength: 71 },
          { city: "Toulouse", strength: 58 },
        ],
      },
      action: { label: "Voter pour votre ville", href: "/#coverage" },
    },
  },
  path: {
    eyebrow: "Du signal au produit",
    title: "Ce que devient votre signalement",
    description:
      "Aucun détail ne part dans le vide. Chaque observation suit le même chemin, du quai jusqu’à l’app.",
    steps: [
      {
        label: "Voir",
        title: "Un détail que le système manque.",
        description:
          "Une sortie fermée, un panneau faux, un message ambigu. Si l’écran ne correspond pas au quai, c’est un signal.",
      },
      {
        label: "Décrire",
        title: "Le moment, le lieu, l’impact.",
        description:
          "Le contexte fait tout : ce que vous faisiez, ce qui manquait, ce que cela a changé pour votre trajet.",
      },
      {
        label: "Améliorer",
        title: "Le signal devient produit.",
        description:
          "Chaque signalement est relu, recoupé avec les données, puis corrigé dans l’app. Le trajet suivant en profite.",
      },
    ],
  },
  cta: {
    title: "Ce que vous voyez aujourd’hui peut améliorer le trajet de demain.",
    description:
      "Un détail précis vaut mieux qu’un grand discours. Racontez-nous le vôtre.",
    action: { label: "Trouver le bon contact", href: "/help" },
  },
} as const;

export type CommunityContent = typeof communityContent;
