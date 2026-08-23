import type { CallToAction } from "./types";

export const marketingPageSlugs = [
  "api",
  "integrations",
  "security",
  "terms",
  "help",
] as const;

export type MarketingPageSlug = (typeof marketingPageSlugs)[number];

export type MarketingPageKind = "product" | "security" | "legal" | "help";

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
