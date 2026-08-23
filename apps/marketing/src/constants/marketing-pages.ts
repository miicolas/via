import type { CallToAction } from "./types";

export const marketingPageSlugs = [
  "api",
  "integrations",
  "analytics",
  "blog",
  "community",
  "security",
  "terms",
  "help",
] as const;

export type MarketingPageSlug = (typeof marketingPageSlugs)[number];

export type MarketingPageKind =
  "product" | "editorial" | "community" | "security" | "legal" | "help";

export type MarketingIconName =
  | "activity"
  | "book-open"
  | "braces"
  | "chart"
  | "check"
  | "clock"
  | "code"
  | "compass"
  | "database"
  | "file-text"
  | "globe"
  | "heart"
  | "key"
  | "layers"
  | "life-buoy"
  | "link"
  | "lock"
  | "map"
  | "message"
  | "plug"
  | "route"
  | "search"
  | "shield"
  | "sparkles"
  | "users"
  | "webhook";

export interface MarketingMetric {
  readonly value: string;
  readonly label: string;
}

export interface MarketingCard {
  readonly icon: MarketingIconName;
  readonly title: string;
  readonly description: string;
  readonly href?: string;
  readonly meta?: string;
}

export interface MarketingSection {
  readonly eyebrow: string;
  readonly title: string;
  readonly description: string;
  readonly cards: readonly MarketingCard[];
}

export interface LegalSection {
  readonly id: string;
  readonly title: string;
  readonly paragraphs: readonly string[];
}

export interface MarketingPageDefinition {
  readonly slug: MarketingPageSlug;
  readonly kind: MarketingPageKind;
  readonly eyebrow: string;
  readonly title: string;
  readonly description: string;
  readonly primaryAction: CallToAction;
  readonly secondaryAction?: CallToAction;
  readonly signal: string;
  readonly metrics?: readonly MarketingMetric[];
  readonly sections?: readonly MarketingSection[];
  readonly legalUpdatedAt?: string;
  readonly legalSections?: readonly LegalSection[];
}

export const marketingPages = {
  api: {
    slug: "api",
    kind: "product",
    eyebrow: "API temps réel",
    title: "La ville ne renvoie jamais deux fois la même réponse.",
    description:
      "Une rame démarre. Un quai se remplit. Un ascenseur s’arrête. L’API Metyro transforme ces mouvements en réponses précises, versionnées et assez rapides pour changer ce que votre produit fait maintenant.",
    primaryAction: {
      label: "Explorer l’API",
      href: "/help#api-et-integrations",
    },
    secondaryAction: { label: "Voir la sécurité", href: "/security" },
    signal: "api",
    metrics: [
      { value: "TEMPS RÉEL", label: "un état, pas une archive" },
      { value: "VERSIONNÉ", label: "le contrat change sans vous casser" },
      { value: "OBSERVABLE", label: "chaque réponse garde son contexte" },
    ],
    sections: [
      {
        eyebrow: "Le contrat",
        title: "Une API doit réduire l’incertitude, pas la déplacer.",
        description:
          "Le réseau est complexe. L’interface ne doit pas l’être. Chaque choix est fait pour que votre équipe comprenne la réponse avant d’ouvrir la documentation.",
        cards: [
          {
            icon: "braces",
            title: "La réponse dit aussi ce qu’elle ignore.",
            description:
              "Temps réel, horaire théorique, fraîcheur et confiance voyagent ensemble. Une estimation ne se déguise jamais en certitude.",
          },
          {
            icon: "webhook",
            title: "Le présent n’attend pas la prochaine synchronisation.",
            description:
              "Les événements arrivent quand le réseau change, pas quand votre tâche planifiée se réveille.",
          },
          {
            icon: "key",
            title: "Une clé n’est pas un passe-partout.",
            description:
              "Chaque environnement reçoit uniquement les droits dont il a besoin, avec rotation prévue dès le premier jour.",
          },
        ],
      },
      {
        eyebrow: "Le réseau traduit",
        title: "Tout ce qu’une carte ne montre pas.",
        description:
          "Un trajet est une suite de contraintes mouvantes. Nous les réunissons dans un vocabulaire commun pour que votre produit puisse enfin raisonner comme un voyageur.",
        cards: [
          {
            icon: "clock",
            title: "Un départ, avec son degré de certitude.",
            description:
              "L’horaire prévu, l’estimation en direct et la fraîcheur du signal restent séparés — donc vraiment utiles.",
          },
          {
            icon: "activity",
            title: "Une perturbation racontée par son impact.",
            description:
              "Pas seulement « trafic perturbé » : la ligne, la portion, la durée, la cause et les voyageurs réellement concernés.",
          },
          {
            icon: "map",
            title: "Une station n’est pas un point sur une carte.",
            description:
              "C’est un ensemble d’accès, de quais, de correspondances et de chemins dont certains ne sont pas possibles pour tout le monde.",
          },
        ],
      },
    ],
  },
  integrations: {
    slug: "integrations",
    kind: "product",
    eyebrow: "Intégrations",
    title: "Vos outils ne devraient pas apprendre la panne par vos voyageurs.",
    description:
      "Metyro fait voyager le signal avant le problème : vers l’écran du hall, le canal d’astreinte, l’app employé ou la donnée qui déclenche votre propre logique.",
    primaryAction: { label: "Voir les connexions", href: "#catalogue" },
    secondaryAction: { label: "Utiliser l’API", href: "/api" },
    signal: "integrations",
    metrics: [
      { value: "ENTRÉE", label: "un événement brut et horodaté" },
      { value: "CONTEXTE", label: "ce qu’il change réellement" },
      { value: "ACTION", label: "le bon outil est déjà prêt" },
    ],
    sections: [
      {
        eyebrow: "Catalogue",
        title:
          "Une information n’est utile qu’au moment où quelqu’un peut agir.",
        description:
          "Nous partons de la décision à prendre, puis remontons jusqu’au signal nécessaire. C’est l’inverse d’un catalogue de connecteurs sans histoire.",
        cards: [
          {
            icon: "message",
            title: "08:42 — l’équipe sait déjà quoi répondre.",
            description:
              "Une ligne s’interrompt. Le canal d’exploitation reçoit la zone, l’impact et l’alternative avant le premier message voyageur.",
          },
          {
            icon: "layers",
            title: "Le hall change avant que la foule n’arrive.",
            description:
              "L’affichage abandonne l’horaire devenu faux et montre immédiatement le prochain choix possible.",
          },
          {
            icon: "database",
            title: "Chaque incident laisse une trace exploitable.",
            description:
              "Le flux opérationnel devient un historique propre, sans perdre l’heure, la source ni la version qui expliquent ce qui s’est passé.",
          },
        ],
      },
      {
        eyebrow: "Fiabilité",
        title:
          "Le silence d’un connecteur ne doit jamais ressembler au calme du réseau.",
        description:
          "Fraîcheur, reprise et journalisation rendent visible la différence entre « rien ne se passe » et « nous ne recevons plus rien ».",
        cards: [
          {
            icon: "check",
            title: "Le mauvais format s’arrête à la frontière.",
            description:
              "Chaque charge utile est contrôlée avant d’entrer dans vos systèmes, avec une erreur qui explique quoi corriger.",
          },
          {
            icon: "activity",
            title: "La fraîcheur est une donnée, pas une intuition.",
            description:
              "Dernier événement reçu, retard observé et état de la chaîne sont lisibles au même endroit.",
          },
          {
            icon: "plug",
            title: "Commencez par un moment qui compte.",
            description:
              "Une ligne, un écran, une alerte. La première intégration prouve sa valeur avant que la suivante ne commence.",
          },
        ],
      },
    ],
  },
  analytics: {
    slug: "analytics",
    kind: "product",
    eyebrow: "Analytics",
    title: "Une moyenne cache toujours quelqu’un qui attend.",
    description:
      "Metyro relie les chiffres du réseau aux moments qu’ils produisent : la pointe qui surgit, l’ascenseur qui manque, la station où cinq minutes ne ressemblent pas aux cinq minutes d’ailleurs.",
    primaryAction: { label: "Découvrir les analyses", href: "#indicateurs" },
    secondaryAction: { label: "Voir les intégrations", href: "/integrations" },
    signal: "analytics",
    metrics: [
      {
        value: "12,84 %",
        label: "des validations entre 8 h et 9 h à Gare du Nord",
      },
      { value: "30,19 %", label: "des validations entre 7 h et 10 h" },
      {
        value: "98,9 %",
        label: "de disponibilité des ascenseurs du métro automatique",
      },
    ],
    sections: [
      {
        eyebrow: "Indicateurs",
        title: "Les moyennes rassurent. Les écarts racontent la vérité.",
        description:
          "Une bonne analyse ne cherche pas seulement la valeur centrale. Elle trouve l’heure, le lieu et les personnes pour qui le réseau cesse de tenir sa promesse.",
        cards: [
          {
            icon: "chart",
            title: "Voir la pointe comme une forme, pas comme un chiffre.",
            description:
              "À Gare du Nord, 30,19 % des validations d’un jour ouvré hors vacances se concentrent entre 7 h et 10 h. Le pic est net ; sa retombée ne l’est pas.",
          },
          {
            icon: "users",
            title: "Comparer ce qui est comparable — et rien d’autre.",
            description:
              "Jour ouvré, vacances, station, réseau, trimestre : chaque chiffre garde son périmètre pour éviter les conclusions élégantes et fausses.",
          },
          {
            icon: "route",
            title: "Un point de pourcentage peut être un trajet impossible.",
            description:
              "La disponibilité moyenne des ascenseurs devient utile quand on la confronte aux objectifs et aux chemins qui n’ont aucune alternative accessible.",
          },
        ],
      },
      {
        eyebrow: "Collaboration",
        title: "Le graphique s’arrête là où la décision commence.",
        description:
          "Chaque vue doit mener à une question suivante : où regarder, qui prévenir, quelle expérience protéger et comment vérifier que l’action a changé quelque chose.",
        cards: [
          {
            icon: "sparkles",
            title: "L’anomalie vient à vous avec son contexte.",
            description:
              "Pas de mur de courbes : le signal inhabituel arrive accompagné de sa période de référence et des stations concernées.",
          },
          {
            icon: "clock",
            title: "L’avant et l’après utilisent la même règle.",
            description:
              "Une amélioration n’existe que si les périodes, les catégories de jours et les définitions restent comparables.",
          },
          {
            icon: "link",
            title: "Le lien partagé emporte la preuve avec lui.",
            description:
              "Filtres, source, période et méthode restent attachés au graphique. Personne ne reçoit une capture orpheline de son contexte.",
          },
        ],
      },
    ],
  },
  blog: {
    slug: "blog",
    kind: "editorial",
    eyebrow: "Le journal Metyro",
    title: "Les transports ont des horaires. La ville, elle, a des habitudes.",
    description:
      "Nous enquêtons sur les minutes que l’on ressent, les signaux que l’on croit et les décisions minuscules qui transforment un déplacement en trajet maîtrisé.",
    primaryAction: { label: "Lire les articles", href: "#a-la-une" },
    signal: "blog",
    sections: [
      {
        eyebrow: "À la une",
        title: "Lire entre les lignes.",
        description:
          "Des récits de terrain, des données replacées dans leur contexte et les choix de produit que nous sommes prêts à expliquer.",
        cards: [
          {
            icon: "route",
            title: "Une minute annoncée n’est pas une minute vécue",
            description:
              "Sur un quai sans information, soixante secondes s’étirent. Avec une estimation crédible et une alternative visible, elles redeviennent du temps que l’on peut décider.",
            meta: "Produit · 6 min",
            href: "/help",
          },
          {
            icon: "activity",
            title: "« Trafic perturbé » ne dit presque rien",
            description:
              "Une mauvaise nouvelle devient utile seulement lorsqu’elle nomme la portion, la durée, l’impact et le prochain choix possible.",
            meta: "Design · 8 min",
            href: "/help",
          },
          {
            icon: "database",
            title: "Le travail invisible derrière « 3 min »",
            description:
              "Sources contradictoires, fraîcheur, repli théorique : l’interface la plus simple repose souvent sur la décision technique la plus exigeante.",
            meta: "Ingénierie · 10 min",
            href: "/api",
          },
          {
            icon: "compass",
            title: "République n’est pas un point. C’est un petit territoire.",
            description:
              "Accès, couloirs, quais, correspondances et habitudes locales : une station possède sa propre géographie vécue.",
            meta: "Ville · 5 min",
            href: "/community",
          },
          {
            icon: "heart",
            title: "L’itinéraire le plus court n’est pas toujours possible",
            description:
              "Concevoir pour l’accessibilité oblige à quitter la ligne droite et à regarder les équipements, les pentes et les interruptions réelles.",
            meta: "Accessibilité · 7 min",
            href: "/community",
          },
          {
            icon: "shield",
            title:
              "La confiance est une fonctionnalité que l’on ne peut pas maquettiser",
            description:
              "Elle se construit dans les données que l’on refuse de collecter, les accès que l’on limite et les promesses que l’on peut vérifier.",
            meta: "Sécurité · 4 min",
            href: "/security",
          },
        ],
      },
    ],
  },
  community: {
    slug: "community",
    kind: "community",
    eyebrow: "Communauté",
    title: "Le réseau parle en données. Le terrain répond en détails.",
    description:
      "Les systèmes savent qu’un train est en retard. Un voyageur sait que la sortie est mal indiquée, que l’ascenseur est condamné ou que le message ne répond pas à la vraie question.",
    primaryAction: { label: "Rejoindre la communauté", href: "#participer" },
    secondaryAction: { label: "Lire le journal", href: "/blog" },
    signal: "community",
    metrics: [
      { value: "VOIR", label: "un détail que le système manque" },
      { value: "DÉCRIRE", label: "le moment, le lieu, l’impact" },
      { value: "AMÉLIORER", label: "transformer le signal en produit" },
    ],
    sections: [
      {
        eyebrow: "Participer",
        title:
          "Pas besoin d’être expert du métro. Il suffit d’avoir vécu le trajet.",
        description:
          "La communauté n’est pas un forum de plus. C’est un endroit où une observation précise peut devenir une meilleure information pour des milliers de déplacements.",
        cards: [
          {
            icon: "message",
            title: "Racontez le moment, pas seulement le problème.",
            description:
              "Où étiez-vous ? Qu’essayiez-vous de faire ? Quelle information manquait ? Le contexte transforme une frustration en piste d’amélioration.",
            href: "/help",
          },
          {
            icon: "users",
            title: "Confrontez l’écran à la vraie station.",
            description:
              "Les plans, libellés et alertes sont relus avec celles et ceux qui les utilisent dans le bruit, la foule et parfois l’urgence.",
          },
          {
            icon: "code",
            title:
              "Détournez l’API vers un usage que nous n’avions pas imaginé.",
            description:
              "Une installation, un outil d’accessibilité, une expérience locale : montrez-nous ce que les mêmes données peuvent devenir ailleurs.",
            href: "/api",
          },
        ],
      },
    ],
  },
  security: {
    slug: "security",
    kind: "security",
    eyebrow: "Sécurité",
    title:
      "Votre trajet est une information intime. Nous le traitons comme tel.",
    description:
      "Metyro doit comprendre le réseau sans construire le journal de votre vie. La protection commence par moins de données, puis se prolonge dans chaque accès et chaque échange.",
    primaryAction: { label: "Voir nos pratiques", href: "#pratiques" },
    secondaryAction: { label: "Consulter les conditions", href: "/terms" },
    signal: "security",
    metrics: [
      { value: "MOINS", label: "collecter seulement ce qui sert" },
      { value: "SÉPARER", label: "limiter chaque accès et chaque rôle" },
      { value: "PROUVER", label: "documenter, vérifier, corriger" },
    ],
    sections: [
      {
        eyebrow: "Pratiques",
        title: "La sécurité n’est pas le cadenas à la fin du projet.",
        description:
          "Elle décide quelles données n’existeront jamais, qui pourra voir les autres et comment nous saurons qu’une limite a été franchie.",
        cards: [
          {
            icon: "lock",
            title: "Ce qui circule n’est jamais laissé à découvert.",
            description:
              "Les échanges utilisent des protocoles modernes et aucun secret capable d’ouvrir nos systèmes ne voyage dans l’app.",
          },
          {
            icon: "key",
            title: "Pouvoir se connecter ne signifie pas pouvoir tout voir.",
            description:
              "Rôle, environnement et besoin opérationnel découpent les accès. Le chemin le plus pratique n’est pas toujours autorisé.",
          },
          {
            icon: "shield",
            title: "Nous partons du principe qu’une barrière peut céder.",
            description:
              "Revue, isolation, surveillance et limitation se superposent pour qu’une erreur ne devienne pas immédiatement un incident.",
          },
          {
            icon: "database",
            title:
              "La donnée la mieux protégée est parfois celle que nous n’avons pas.",
            description:
              "Chaque collecte doit répondre à un usage clair. Sans raison produit défendable, elle n’entre pas dans Metyro.",
          },
          {
            icon: "activity",
            title: "Le calme apparent ne suffit pas.",
            description:
              "Les comportements anormaux sont détectés, qualifiés et reliés à une procédure avant que l’improvisation ne commence.",
          },
          {
            icon: "file-text",
            title: "Une promesse de sécurité doit laisser des preuves.",
            description:
              "Décisions, responsabilités et corrections importantes restent traçables pour pouvoir être relues et contestées.",
          },
        ],
      },
    ],
  },
  terms: {
    slug: "terms",
    kind: "legal",
    eyebrow: "Conditions d’utilisation",
    title: "Pas besoin de jargon pour vous dire ce que vous acceptez.",
    description:
      "Voici ce que Metyro fait, ce que le service ne peut pas garantir, ce que nous attendons de vous et les droits que vous gardez. Si une phrase reste obscure, c’est à nous de mieux l’écrire.",
    primaryAction: { label: "Lire les conditions", href: "#acceptation" },
    secondaryAction: { label: "Obtenir de l’aide", href: "/help" },
    signal: "terms",
    legalUpdatedAt: "23 août 2026",
    legalSections: [
      {
        id: "acceptation",
        title: "1. Acceptation des conditions",
        paragraphs: [
          "En utilisant Metyro, vous acceptez les présentes conditions. Si vous n’acceptez pas une disposition, vous devez cesser d’utiliser le service.",
          "Vous devez être en capacité juridique d’accepter ces conditions dans votre pays de résidence. Lorsque vous utilisez Metyro pour une organisation, vous confirmez être autorisé à l’engager.",
        ],
      },
      {
        id: "service",
        title: "2. Le service Metyro",
        paragraphs: [
          "Metyro rassemble et présente des informations de transport afin de faciliter la préparation et le suivi des trajets. Les horaires, itinéraires et perturbations peuvent provenir de sources tierces et évoluer sans préavis.",
          "Nous faisons notre possible pour fournir une information exacte et actuelle, mais Metyro ne remplace pas les consignes officielles des opérateurs et autorités de transport.",
        ],
      },
      {
        id: "usage",
        title: "3. Utilisation acceptable",
        paragraphs: [
          "Vous vous engagez à ne pas perturber le service, contourner ses protections, extraire massivement ses données ou l’utiliser d’une manière contraire à la loi ou aux droits d’autrui.",
          "L’accès automatisé est réservé aux interfaces et conditions prévues à cet effet, notamment l’API lorsqu’elle est mise à disposition.",
        ],
      },
      {
        id: "accounts",
        title: "4. Comptes et sécurité",
        paragraphs: [
          "Vous êtes responsable de la confidentialité de vos identifiants et des actions réalisées depuis votre compte. Informez-nous rapidement si vous soupçonnez un accès non autorisé.",
          "Nous pouvons suspendre un accès lorsque cela est nécessaire pour protéger Metyro, ses utilisateurs ou un tiers.",
        ],
      },
      {
        id: "content",
        title: "5. Contenus et propriété intellectuelle",
        paragraphs: [
          "Metyro, son identité, son interface et ses contenus sont protégés par les lois applicables. Les présentes conditions ne vous transfèrent aucun droit de propriété sur le service.",
          "Lorsque vous nous transmettez un retour, vous nous autorisez à l’utiliser pour améliorer le produit, sans obligation de rémunération ni de publication.",
        ],
      },
      {
        id: "liability",
        title: "6. Disponibilité et responsabilité",
        paragraphs: [
          "Le service est fourni selon sa disponibilité. Des interruptions peuvent intervenir pour maintenance, sécurité ou en raison d’événements indépendants de notre volonté.",
          "Dans les limites permises par la loi, Metyro ne saurait être responsable d’une décision de trajet prise uniquement sur la base d’une information retardée, incomplète ou fournie par un tiers.",
        ],
      },
      {
        id: "changes",
        title: "7. Évolution des conditions",
        paragraphs: [
          "Nous pouvons mettre à jour ces conditions pour refléter une évolution du service ou du cadre légal. La date de dernière mise à jour est indiquée en haut de cette page.",
          "En cas de modification importante, nous fournirons une information raisonnable avant son entrée en vigueur lorsque la loi l’exige.",
        ],
      },
      {
        id: "contact",
        title: "8. Nous contacter",
        paragraphs: [
          "Pour toute question concernant ces conditions, utilisez la page d’aide. Nous vous orienterons vers l’interlocuteur approprié.",
        ],
      },
    ],
  },
  help: {
    slug: "help",
    kind: "help",
    eyebrow: "Centre d’aide",
    title: "Le train arrive. Allons droit à la réponse.",
    description:
      "Pas de catégories internes ni de mode d’emploi interminable. Choisissez le moment qui bloque votre trajet et retrouvez le geste qui le débloque.",
    primaryAction: { label: "Parcourir l’aide", href: "#categories" },
    signal: "help",
    sections: [
      {
        eyebrow: "Catégories",
        title: "À quel moment le trajet s’est-il arrêté ?",
        description:
          "Chaque entrée part d’une situation vécue. Les noms de fonctionnalités viennent après.",
        cards: [
          {
            icon: "compass",
            title: "Je viens d’ouvrir Metyro",
            description:
              "Comprendre l’accueil, choisir les informations utiles et préparer le premier trajet sans tout configurer.",
          },
          {
            icon: "route",
            title: "Je ne trouve pas le bon trajet",
            description:
              "Reformuler une recherche, choisir une autre origine et comprendre pourquoi un itinéraire n’apparaît pas.",
          },
          {
            icon: "activity",
            title: "Je veux être prévenu avant de partir",
            description:
              "Choisir une ligne, un moment et un niveau d’alerte sans transformer chaque incident en notification.",
          },
          {
            icon: "life-buoy",
            title: "L’écran ne correspond pas au quai",
            description:
              "Vérifier la fraîcheur du signal, distinguer temps réel et horaire théorique, puis signaler un écart précis.",
          },
          {
            icon: "lock",
            title: "Je veux savoir ce que Metyro connaît de moi",
            description:
              "Comprendre chaque autorisation, les données réellement utilisées et les choix disponibles sur l’appareil.",
            href: "/security",
          },
          {
            icon: "braces",
            title: "Je construis avec les données Metyro",
            description:
              "Obtenir un accès, lire la première réponse et comprendre la fraîcheur, les limites et les erreurs.",
            href: "/api",
          },
        ],
      },
      {
        eyebrow: "Questions fréquentes",
        title: "Trois réponses avant la prochaine rame.",
        description:
          "Courtes, concrètes et écrites pour reprendre le trajet sans ouvrir un deuxième onglet.",
        cards: [
          {
            icon: "clock",
            title: "Pourquoi un horaire change-t-il ?",
            description:
              "Metyro privilégie le temps réel lorsqu’il est disponible et revient à l’horaire théorique si le signal est interrompu.",
          },
          {
            icon: "activity",
            title: "Comment activer une alerte ?",
            description:
              "Ouvrez une ligne ou une station, choisissez le symbole de notification puis ajustez les moments souhaités.",
          },
          {
            icon: "map",
            title: "Pourquoi ma station n’apparaît-elle pas ?",
            description:
              "Vérifiez la zone de couverture, l’orthographe ou l’autorisation de localisation si vous recherchez à proximité.",
          },
        ],
      },
    ],
  },
} as const satisfies Record<MarketingPageSlug, MarketingPageDefinition>;

export function getMarketingPage(
  slug: string,
): MarketingPageDefinition | undefined {
  return marketingPages[slug as MarketingPageSlug];
}
