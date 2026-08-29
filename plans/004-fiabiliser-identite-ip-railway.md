# Plan 004 : Fonder les quotas anonymes sur l’adresse injectée par Railway

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « STOP » se produit, arrêter et remonter le problème sans
> improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/api/src/http/ip-identity.ts apps/api/src/http/ip-identity.test.ts`
> Si un fichier modifiable du périmètre a changé depuis la rédaction du plan,
> comparer le code courant aux extraits ci-dessous. En cas de divergence
> structurelle, traiter cela comme une condition STOP.

## Statut

- **Priorité** : P1
- **Effort** : S
- **Risque** : MED — une mauvaise hypothèse de proxy peut regrouper des utilisateurs légitimes sous une seule identité
- **Dépend de** : aucun autre plan
- **Catégorie** : sécurité / bug
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

L’identité anonyme qui protège les quotas PRIM, OpenAI, signalements, partages
et votes préfère aujourd’hui `cf-connecting-ip`, puis la première valeur de
`x-forwarded-for`. Le déploiement mobile appelle pourtant directement le domaine
Railway, pas Cloudflare. Un client peut donc fournir ces headers et changer son
HMAC à volonté, ce qui vide les budgets globaux malgré les limites par personne.

Railway documente `X-Real-IP` comme l’adresse client ajoutée à la requête remise
au service. La cible ne fait confiance qu’à cette frontière, valide une IPv4 ou
IPv6 unique, ignore toujours `CF-Connecting-IP` et `X-Forwarded-For`, puis garde
le HMAC comme seule valeur persistable.

## État actuel

### Fichiers et responsabilités

- `apps/api/src/http/ip-identity.ts` — choisit l’adresse brute et calcule son HMAC.
- `apps/api/src/http/ip-identity.test.ts` — encode actuellement la préférence Cloudflare.
- `apps/api/src/app.ts` — fournit paresseusement le hash aux procédures (`:128-136`) ; contexte seulement, ne pas modifier.
- `apps/via/Configuration/Release.xcconfig` — confirme le host Railway de release ; contexte seulement.
- `docs/adr/0003-api-reservee-aux-clients-de-premiere-partie.md` — fixe les limites du client gate ; contexte seulement.

### Extraits à reconnaître

`apps/api/src/http/ip-identity.ts:3-11` fait confiance à deux valeurs que le
client peut présenter :

```ts
export function requestIP(request: Request) {
  return (
    request.headers.get("cf-connecting-ip")?.trim() ||
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    "unavailable"
  );
}

/** The raw network address never leaves this stack frame and is never persisted. */
export function requestIPHash(request: Request, secret: string) {
  return createHmac("sha256", secret).update(requestIP(request)).digest("hex");
}
```

`apps/api/src/http/ip-identity.test.ts:5-11` sanctuarise ce mauvais ordre :

```ts
const request = new Request("https://via.example/api/reports", {
  headers: {
    "cf-connecting-ip": "203.0.113.7",
    "x-forwarded-for": "198.51.100.2",
  },
});
expect(requestIP(request)).toBe("203.0.113.7");
```

`apps/via/Configuration/Release.xcconfig:3-5` établit la topologie actuelle :

```xcconfig
VIA_API_SCHEME = https:
VIA_API_BASE_URL = $(VIA_API_SCHEME)$(VIA_URL_SLASH)$(VIA_URL_SLASH)usevia.up.railway.app/api
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) RELEASE
```

La documentation de plateforme à vérifier avant implémentation est
`https://docs.railway.com/networking/public-networking/specs-and-limits` : elle
nomme `X-Real-IP` comme header ajouté par le proxy Railway. Ne recopier aucune
valeur de configuration ou secret du déploiement.

ADR-0003:30-34 précise que la clé iOS reste extractible et **ne remplace pas les
quotas par personne**. Le correctif doit donc renforcer l’identité de quota sans
transformer le client gate, sans fermer `/api/health` et sans remettre en cause
le fail-open de configuration accepté par cet ADR.

## Commandes utiles

| But                | Commande                                         | Résultat attendu       |
| ------------------ | ------------------------------------------------ | ---------------------- |
| Test ciblé         | `bun test apps/api/src/http/ip-identity.test.ts` | tous les tests passent |
| Tests API          | `bun run --filter=@via/api test`                 | exit 0                 |
| Typecheck API      | `bun run --filter=@via/api typecheck`            | exit 0                 |
| Typecheck monorepo | `bun run typecheck`                              | 6 tâches réussies      |

## Périmètre

### Fichiers autorisés

- `apps/api/src/http/ip-identity.ts`
- `apps/api/src/http/ip-identity.test.ts`
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- `apps/api/src/app.ts` et tous les consommateurs de `requestIPHash` : leur
  interface ne doit pas changer.
- Les limites numériques, namespaces Redis et politiques fail-open/fail-closed.
- Le client gate, CORS, Better Auth et App Attest.
- La configuration Railway, les domaines, secrets et fichiers `.env`.
- Une prise en charge Cloudflare hypothétique : aucun proxy Cloudflare n’est
  présent dans la topologie documentée.

## Git

- Branche recommandée : `codex/004-trust-railway-client-ip`.
- Commit recommandé : `fix(api): trust Railway client IP for anonymous quotas`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Remplacer le test de préférence par des tests anti-usurpation

Réécrire `ip-identity.test.ts` avec uniquement des adresses réservées à la
documentation. Couvrir explicitement :

1. une IPv4 valide dans `x-real-ip` est utilisée ;
2. une IPv6 valide dans `x-real-ip` est utilisée ;
3. à `x-real-ip` identique, faire varier `cf-connecting-ip` et
   `x-forwarded-for` ne change ni `requestIP` ni `requestIPHash` ;
4. sans `x-real-ip`, ces deux headers non fiables sont ignorés et la valeur est
   `unavailable` ;
5. une valeur vide, multiple (`a, b`), avec port ou non-IP est refusée et donne
   `unavailable` ;
6. le HMAC est stable pour la même adresse, différent pour deux adresses et ne
   contient jamais l’adresse brute.

Ne tester aucune adresse réelle et ne rendre public aucun secret : utiliser une
chaîne statique propre au test pour la clé HMAC.

**Vérifier** : `bun test apps/api/src/http/ip-identity.test.ts` doit échouer sur
les assertions `x-real-ip` avant la correction, et pour aucune autre raison.

### 2. Faire de `X-Real-IP` l’unique entrée réseau fiable

Dans `ip-identity.ts`, lire uniquement `request.headers.get('x-real-ip')`.
Normaliser les espaces périphériques, puis valider que la valeur représente
exactement une IPv4 ou IPv6 au moyen de `isIP` de `node:net`. Refuser une liste,
un port, une chaîne vide ou tout autre texte. Retourner la sentinelle constante
`unavailable` lorsque la validation échoue.

Ne jamais retomber sur `cf-connecting-ip`, `x-forwarded-for`, `forwarded`, une
query string ou un header défini par l’application. Conserver le commentaire et
l’invariant de `requestIPHash` : l’adresse brute ne quitte pas cette pile, seul
le HMAC SHA-256 est fourni aux quotas.

**Vérifier** : `bun test apps/api/src/http/ip-identity.test.ts` → tous les cas
passent, notamment celui où deux requêtes aux headers CF/XFF différents ont le
même hash lorsque `x-real-ip` est identique.

### 3. Vérifier les consommateurs sans changer leurs politiques

Exécuter la suite API. Ne modifier aucune attente de quota, car seule la source
de l’identité change. Rechercher les copies éventuelles de parsing de proxy et
confirmer qu’aucun autre module ne fabrique une identité anonyme depuis CF/XFF.

**Vérifier** :

```bash
rg -n "cf-connecting-ip|x-forwarded-for" apps/api/src
bun run --filter=@via/api test
bun run --filter=@via/api typecheck
```

Résultats attendus : `rg` ne retourne aucune occurrence de production (une
occurrence dans le test anti-usurpation est attendue), puis tests et typecheck
sortent avec le code 0.

### 4. Vérifier le monorepo

**Vérifier** : `bun run typecheck` → les 6 tâches réussissent. Aucun fichier de
configuration ou secret ne doit avoir été lu ou modifié.

## Plan de test

- Tests unitaires déterministes uniquement dans `ip-identity.test.ts`.
- IPv4 et IPv6 valides ; espaces périphériques ; valeurs absente, vide,
  multiple, avec port et syntaxiquement invalide.
- Régression de sécurité centrale : deux jeux de CF/XFF forgés ne peuvent pas
  modifier le HMAC sous une même `x-real-ip`, et ne créent aucune identité sans
  elle.
- Propriété de confidentialité : le résultat HMAC ne contient jamais l’adresse.
- Suite API complète pour confirmer que les politiques de quotas n’ont pas été
  réécrites.

## Critères de fin

- [ ] `requestIP` ne lit que `x-real-ip` et valide une IP unique.
- [ ] `cf-connecting-ip` et `x-forwarded-for` sont ignorés même lorsqu’ils sont présents.
- [ ] Une IP absente ou invalide produit exactement `unavailable`.
- [ ] Les tests prouvent que des headers forgés ne changent pas le hash de quota.
- [ ] Aucun appelant, seuil ou namespace de quota n’est modifié.
- [ ] Tests API et typechecks package/racine sortent avec le code 0.
- [ ] Aucun fichier hors périmètre n’est modifié, hormis le statut du plan.

## Conditions STOP

Arrêter et remonter le problème si :

- la documentation Railway courante ne garantit plus `X-Real-IP` ou indique que
  le header client n’est pas remplacé à l’edge ;
- la production passe désormais par Cloudflare, un load balancer supplémentaire
  ou un private network qui change la chaîne de confiance ;
- Railway remet une liste d’adresses ou une adresse avec port plutôt qu’une IP
  unique ;
- la correction exige de lire une variable secrète ou de modifier la
  configuration de déploiement ;
- un consommateur dépend de la valeur brute plutôt que du HMAC ;
- une vérification échoue deux fois après correction raisonnable.

## Notes de maintenance

- La confiance appartient au dernier proxy administré par Via. Toute évolution
  de topologie doit réexaminer ce module avant de changer simplement le nom du
  header.
- `unavailable` regroupe volontairement les requêtes dont la plateforme ne peut
  attester l’adresse ; ne jamais réintroduire un fallback client « pour mieux
  distinguer » les utilisateurs.
- App Attest reste un durcissement distinct : il prouve l’application/appareil,
  pas l’adresse réseau, et n’appartient pas à ce plan.
- En review, vérifier à la fois l’anti-spoofing et le maintien de l’IPv6.
