/**
 * Comment le site appelle l’API, écrit une seule fois.
 *
 * Trois surfaces s’en servent — le vote de couverture, l’état des lignes et le
 * trajet partagé — et la règle qu’elles partagent est sensible : quelle origine
 * on appelle, et à qui on confie la clé partagée. Répétée par fichier, elle
 * dérive ; renommer l’en-tête ou changer le repli de production laisserait
 * silencieusement une page derrière.
 */

/**
 * `NEXT_PUBLIC_` parce que le vote part du navigateur et doit pouvoir partir :
 * le relayer par un route handler donnerait à chaque voix la même adresse
 * serveur, et l’API compte une voix par adresse.
 *
 * Non renseignée en production, la valeur est `null` : une variable manquante
 * rend la surface muette plutôt que de pointer un site en ligne vers localhost.
 */
export function apiOrigin(): string | null {
  const configured = process.env.NEXT_PUBLIC_API_URL?.trim().replace(/\/+$/, "");
  if (configured) return configured;
  return process.env.NODE_ENV === "production" ? null : "http://localhost:3000";
}

/**
 * L’API répond au site et à l’application, à personne d’autre. Depuis le
 * navigateur c’est l’en-tête `Origin` qui en décide, qu’aucune page ne peut
 * forger pour une autre. Côté serveur il n’y a pas d’origine à envoyer, alors le
 * rendu présente la clé partagée — délibérément sans `NEXT_PUBLIC_`, pour
 * qu’elle n’atteigne jamais un bundle, et sous garde pour qu’un appel navigateur
 * ne puisse pas la réclamer.
 */
export function serverHeaders(): HeadersInit {
  if (typeof window !== "undefined") return {};
  const key = process.env.VIA_SITE_CLIENT_KEY?.trim();
  return key ? { "x-via-client-key": key } : {};
}

/**
 * Trois secondes, pas davantage. Ce que ces requêtes rapportent est une
 * surcouche — un bandeau, des compteurs ; ce qu’un long délai coûte est le rendu
 * de toute la page, et sur Railway le service d’API peut être en train de se
 * réveiller. Toute panne se solde donc par `null`, et la page qui perd sa
 * surcouche reste juste et complète.
 */
export const API_REQUEST_TIMEOUT_MS = 3_000;

export function boundedApiSignal(
  upstream?: AbortSignal,
  timeoutMs: number = API_REQUEST_TIMEOUT_MS,
): AbortSignal {
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) {
    throw new RangeError("API request timeout must be a positive finite number.");
  }
  const timeout = AbortSignal.timeout(timeoutMs);
  return upstream ? AbortSignal.any([upstream, timeout]) : timeout;
}

export async function readJson<T>(path: string, revalidate: number): Promise<T | null> {
  const origin = apiOrigin();
  if (!origin) return null;

  try {
    const response = await fetch(`${origin}${path}`, {
      headers: serverHeaders(),
      signal: boundedApiSignal(),
      next: { revalidate },
    });
    if (!response.ok) return null;
    return (await response.json()) as T;
  } catch {
    return null;
  }
}

/**
 * Comme `readJson`, mais la réponse doit correspondre au schéma partagé avant
 * d’atteindre une page. Une forme inattendue se solde par `null` — la même
 * panne qu’un service muet — plutôt que par un `undefined` qui traverse le
 * rendu jusqu’à l’affichage.
 */
export async function readValidated<T>(
  path: string,
  revalidate: number,
  schema: { safeParse: (value: unknown) => { success: true; data: T } | { success: false } },
): Promise<T | null> {
  const body = await readJson<unknown>(path, revalidate);
  if (body === null) return null;
  const parsed = schema.safeParse(body);
  return parsed.success ? parsed.data : null;
}
