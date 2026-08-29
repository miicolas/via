# Plan 009: Confiner l’extraction des archives GTFS dans leur répertoire temporaire

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « STOP » se produit, arrêter et remonter le problème sans
> improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/worker/package.json bun.lock apps/worker/src/prim/extract-gtfs-archive.ts apps/worker/src/prim/extract-gtfs-archive.test.ts apps/worker/src/prim/sync-gtfs.ts apps/worker/src/prim/sync-gtfs.test.ts`
> Le worktree contenait déjà, au moment de la rédaction, l’ajout utilisateur
> `"import-fountains": "bun --env-file=../../.env src/fountains/cli.ts"` dans
> `apps/worker/package.json`. Cette ligne doit être conservée exactement ; sa
> présence seule n’est pas une condition STOP. Toute autre divergence
> structurelle doit être réconciliée avant de continuer.

## Statut

- **Priorité** : P1
- **Effort** : M (remplacement de dépendance, extracteur dédié et fixtures hostiles)
- **Risque** : MED — le cron GTFS dépend de la compatibilité réelle avec l’archive IDFM et de la fermeture correcte des streams
- **Dépend de** : `plans/008-upgrade-nextjs-security.md` (les deux plans modifient `bun.lock`; exécuter 008 d’abord)
- **Catégorie** : security / migration
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

Le chemin de production télécharge une archive distante puis l’extrait avec
`extract-zip@2.0.1`. Cette version est la dernière publiée et reste affectée par
[GHSA-jmr9-qjv8-65gv](https://github.com/advisories/GHSA-jmr9-qjv8-65gv) :
les cibles de liens symboliques ne sont pas validées, sans version corrigée à
installer. Les hôtes de téléchargement sont limités à IDFM/OpenDataSoft, mais
une archive amont compromise serait tout de même traitée avec les droits du
cron. La cible est un lecteur ZIP maintenu qui expose chaque entrée, puis une
écriture locale contrôlée par Via : aucun chemin ne sort de `feed/`, aucun lien
n’est créé ou suivi, et l’extraction reste streaming.

## État actuel

### Fichiers et responsabilités

- `apps/worker/package.json` — dépendances du worker ; contient `extract-zip` et un ajout fountains non lié à préserver.
- `bun.lock` — résout `extract-zip@2.0.1` et son ancien `yauzl@2.x` transitif.
- `apps/worker/src/prim/sync-gtfs.ts` — orchestre téléchargement, extraction, import et nettoyage du dossier temporaire.
- `apps/worker/src/prim/sync-gtfs.test.ts` — caractérise l’ordre des adapters et la conservation des validateurs HTTP en cas d’échec.
- `apps/worker/src/prim/download-gtfs.ts` — limite déjà le téléchargement aux hôtes HTTPS approuvés ; ne doit pas être modifié.

### Extraits à reconnaître avant modification

`apps/worker/package.json:17-22` :

```json
"dependencies": {
  "@via/db": "workspace:*",
  "csv-parse": "^6.1.0",
  "drizzle-orm": "^0.45.2",
  "extract-zip": "^2.0.1"
}
```

La modification utilisateur à préserver se trouve dans les scripts :

```json
"import-elevators": "bun --env-file=../../.env src/elevators/cli.ts",
"import-fountains": "bun --env-file=../../.env src/fountains/cli.ts",
"import-station-peaks": "bun --env-file=../../.env src/station-peaks/cli.ts"
```

`apps/worker/src/prim/sync-gtfs.ts:55-77` monte actuellement l’adapter dangereux :

```ts
const productionAdapters: PrimGtfsSyncAdapters = {
  // ...
  async extract(archive, destination) {
    await mkdir(destination, { recursive: true });
    await extract(archive, { dir: destination });
  },
};
```

`apps/worker/src/prim/sync-gtfs.ts:93-110` crée un dossier neuf, importe seulement
après extraction et le supprime toujours :

```ts
const temporaryDirectory = await adapters.createTemporaryDirectory();
const archive = join(temporaryDirectory, "snapshot.zip");
const feed = join(temporaryDirectory, "feed");
try {
  // téléchargement
  await adapters.extract(archive, feed);
  const imported = await adapters.importSnapshot(feed);
  await adapters.saveValidators(downloaded.validators);
  return imported;
} finally {
  await adapters.removeTemporaryDirectory(temporaryDirectory);
}
```

`apps/worker/src/prim/download-gtfs.ts:9-12` limite déjà la provenance :

```ts
const TRUSTED_DOWNLOAD_HOSTS = new Set([
  "data.iledefrance-mobilites.fr",
  "eu.ftp.opendatasoft.com",
]);
```

### Conventions et choix techniques

- Le worker utilise TypeScript strict, modules ESM, imports Node explicites et
  quotes simples. Les tests emploient `bun:test` et nettoient leurs dossiers
  temporaires dans un `finally`; suivre `download-gtfs.test.ts:8-65`.
- Garder l’interface `PrimGtfsSyncAdapters.extract(archive, destination)` : les
  tests d’orchestration injectent cet adapter et n’ont pas à connaître la
  bibliothèque ZIP.
- Utiliser `yauzl@^3.4.0` avec `@types/yauzl@^3.4.0`. Cette branche lit le
  répertoire central, valide les noms et tailles déclarées, expose une
  itération paresseuse et est maintenue. Via doit malgré tout refaire son propre
  contrôle de confinement avant chaque écriture.
- Utiliser `yazl@^3.3.1` et `@types/yazl@^3.3.1` uniquement en
  `devDependencies` pour construire de petites archives de test en mémoire.
- Ne pas appeler une méthode d’extraction en masse d’une dépendance. Le code Via
  ouvre chaque entrée et crée lui-même chaque dossier/fichier.
- Le dossier de destination vient de `mkdtemp`; ne pas extraire vers un dossier
  utilisateur ou persistant.

## Commandes utiles

| But                | Commande                                                                                     | Résultat attendu                                                                   |
| ------------------ | -------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Test extracteur    | `bun test apps/worker/src/prim/extract-gtfs-archive.test.ts`                                 | tous les cas de confinement passent                                                |
| Tests PRIM         | `bun test apps/worker/src/prim/sync-gtfs.test.ts apps/worker/src/prim/download-gtfs.test.ts` | tous passent                                                                       |
| Tests worker       | `bun run --filter=@via/worker test`                                                          | tous les tests passent, intégration DB éventuellement skip selon son gate existant |
| Typecheck worker   | `bun run --filter=@via/worker typecheck`                                                     | exit 0                                                                             |
| Lock reproductible | `bun install --frozen-lockfile`                                                              | exit 0, aucun diff ajouté                                                          |
| Avis retiré        | `bun audit --production`                                                                     | ne liste ni `GHSA-jmr9-qjv8-65gv` ni `extract-zip@2.0.1`                           |

## Références conseillées

- Avis officiel :
  [GHSA-jmr9-qjv8-65gv](https://github.com/advisories/GHSA-jmr9-qjv8-65gv).
- API et principes du lecteur :
  [documentation officielle de yauzl](https://github.com/thejoshwolfe/yauzl).
  Utiliser l’ouverture Promise et l’itération paresseuse documentées par la
  version retenue ; ne pas recopier un exemple d’extraction globale.

## Périmètre

### Fichiers autorisés

- `apps/worker/package.json`
- `bun.lock`
- `apps/worker/src/prim/extract-gtfs-archive.ts` (nouveau)
- `apps/worker/src/prim/extract-gtfs-archive.test.ts` (nouveau)
- `apps/worker/src/prim/sync-gtfs.ts`
- `apps/worker/src/prim/sync-gtfs.test.ts` uniquement si un test d’orchestration supplémentaire est nécessaire
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- `apps/worker/src/fountains/**`, `railway.fountains.json`, le script
  `import-fountains` et toutes les modifications fountains déjà présentes.
- Le téléchargement, les hôtes approuvés, les tokens PRIM et les délais HTTP.
- L’import SQL/GTFS, les validateurs ETag/Last-Modified et le cache réseau.
- Les limites produit sur la taille d’un feed ; ce plan garantit le streaming
  et le confinement, mais ne choisit pas arbitrairement un plafond qui pourrait
  rejeter le feed IDFM légitime.
- Les autres dépendances ou avis de sécurité.
- L’ajout d’un binaire `unzip`, d’un appel shell ou d’une dépendance native.

## Git

- Branche recommandée : `codex/009-secure-gtfs-archive-extraction`.
- Commits logiques, par exemple
  `fix(worker): confine GTFS archive extraction`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Remplacer la dépendance sans perdre le travail fountains

Avant toute commande Bun, enregistrer le diff de `apps/worker/package.json` et
confirmer que `import-fountains` est présent. Retirer `extract-zip`; ajouter
`yauzl` en dépendance de production et les types/constructeur d’archives en
devDependencies :

```bash
bun remove --cwd apps/worker extract-zip
bun add --cwd apps/worker yauzl@^3.4.0
bun add --cwd apps/worker --dev @types/yauzl@^3.4.0 yazl@^3.3.1 @types/yazl@^3.3.1
```

Si une version plus récente est proposée, rester dans ces mêmes majeures et
vérifier ses avis officiels avant de l’accepter. Examiner le diff : la ligne
`import-fountains` doit rester présente ; aucun script worker ne doit disparaître.

**Vérifier** :

```bash
rg -n 'import-fountains' apps/worker/package.json
if rg -q 'extract-zip' apps/worker/package.json bun.lock; then exit 1; fi
bun install --frozen-lockfile
```

Résultat attendu : une occurrence du script fountains, aucune occurrence de
`extract-zip`, puis exit 0 sans nouveau diff.

### 2. Écrire un extracteur entrée par entrée appartenant à Via

Créer `apps/worker/src/prim/extract-gtfs-archive.ts` et exporter une seule
fonction :

```ts
export async function extractGtfsArchive(
  archive: string,
  destination: string,
): Promise<void>;
```

L’algorithme doit respecter **toutes** les propriétés suivantes :

1. résoudre une fois `destination` en chemin absolu et le créer ;
2. ouvrir l’archive avec l’API paresseuse de `yauzl`, validation des noms et des
   tailles activée ;
3. traiter une seule entrée à la fois afin de ne pas charger le feed en mémoire ;
4. remplacer `\\` par `/` avant validation, puis rejeter nom vide, NUL, chemin
   absolu, préfixe de lecteur, et tout segment `..` ;
5. calculer la cible avec `resolve(root, normalizedName)` et exiger qu’elle soit
   strictement sous `root + sep` ; ne jamais se contenter d’un préfixe texte qui
   accepterait un dossier frère au nom similaire ;
6. distinguer dossiers et fichiers à partir du nom et, pour les archives Unix,
   des bits de type dans `externalFileAttributes` ; rejeter explicitement lien
   symbolique et tout type spécial ;
7. créer les parents avec `mkdir({ recursive: true })`, puis un fichier régulier
   neuf avec le flag exclusif `wx` et un mode local sobre ;
8. envoyer le read stream dans ce fichier avec `node:stream/promises.pipeline` ;
9. ne jamais appeler `symlink`, `link`, `chmod` avec le mode de l’archive, ni une
   méthode `extract()` fournie par une dépendance ;
10. fermer le ZIP et le descripteur de sortie dans tous les chemins d’erreur.

Une entrée de lien ne doit pas être « assainie » en fichier texte : elle doit
faire échouer l’archive entière avant l’import. Un doublon de nom doit échouer
grâce à `wx`, pas écraser silencieusement l’entrée précédente.

**Vérifier** : `bun run --filter=@via/worker typecheck` → exit 0.

### 3. Caractériser le confinement avec de vraies archives ZIP minuscules

Créer `extract-gtfs-archive.test.ts`. Utiliser `yazl` pour construire les
archives normales dans un dossier `mkdtemp`. Pour les noms qu’un constructeur
sûr refuse de produire, créer une fixture ZIP minimale dans le test ou une
constante base64 documentée ; ne pas committer un gros binaire opaque. Une
fixture mutée doit conserver la même longueur de nom dans l’en-tête local et le
répertoire central afin de rester un ZIP valide.

Couvrir au minimum :

- un feed plat avec `stops.txt` et `routes.txt` est extrait avec les octets exacts ;
- un sous-dossier légitime reste sous la racine ;
- un nom contenant un segment parent est rejeté et aucun fichier sentinelle
  n’apparaît à côté du dossier de destination ;
- la variante avec séparateurs Windows est rejetée de la même façon ;
- un chemin absolu ou un préfixe de lecteur est rejeté ;
- une entrée marquée lien symbolique Unix est rejetée et `lstat` ne trouve
  aucun lien dans ou hors de la destination ;
- deux entrées visant la même cible sont rejetées sans écrasement ;
- une archive tronquée/malformée rejette la Promise et ferme les ressources.

Chaque test crée et supprime son propre dossier dans un `try/finally`, comme
`download-gtfs.test.ts`. Les messages d’erreur doivent nommer la catégorie
(`unsafe path`, `unsupported entry type`, `duplicate`) sans réimprimer de
contenu sensible.

**Vérifier** :

```bash
bun test apps/worker/src/prim/extract-gtfs-archive.test.ts
```

Résultat attendu : tous les cas listés passent ; aucun fichier de fixture ou de
sortie ne reste dans le dépôt.

### 4. Brancher l’extracteur sur le chemin de production

Dans `sync-gtfs.ts`, retirer l’import `extract-zip` et importer
`extractGtfsArchive`. Garder l’adapter et son interface inchangés :

```ts
async extract(archive, destination) {
  await extractGtfsArchive(archive, destination);
}
```

La création de la destination appartient désormais à la fonction dédiée ; ne
la dupliquer dans l’adapter que si le test de l’extracteur prouve que l’API
l’exige. Ne changer ni l’ordre `download → extract → import → saveValidators`
ni le `finally` de nettoyage.

**Vérifier** :

```bash
bun test apps/worker/src/prim/sync-gtfs.test.ts apps/worker/src/prim/download-gtfs.test.ts
```

Résultat attendu : tous les tests passent et l’ordre d’événements existant est
inchangé.

### 5. Valider le worker et la résolution finale

Exécuter toute la suite worker et le typecheck. Le test d’intégration GTFS garde
son gate de base jetable ; ne pas pointer ce plan vers une base de production.

**Vérifier** :

```bash
bun run --filter=@via/worker typecheck
bun run --filter=@via/worker test
bun install --frozen-lockfile
if bun audit --production 2>&1 | rg -q 'GHSA-jmr9-qjv8-65gv|extract-zip@2\.0\.1'; then exit 1; fi
```

Résultat attendu : toutes les commandes sortent 0, les tests worker passent
(hors éventuel skip d’intégration déjà prévu), et l’avis ciblé est absent.

## Plan de test

- Nouveau fichier `extract-gtfs-archive.test.ts`, construit sur le pattern de
  dossier temporaire et nettoyage de `download-gtfs.test.ts`.
- Cas heureux : fichiers plats et dossier imbriqué, contenu exact.
- Régressions sécurité : parent POSIX, parent Windows, absolu/lecteur, lien
  symbolique, doublon et archive corrompue.
- Orchestration existante : `sync-gtfs.test.ts` confirme que l’import ne démarre
  qu’après extraction et que le dossier est supprimé même en cas d’échec.
- Aucun test ne doit créer ou suivre un vrai lien hors d’un dossier temporaire ;
  vérifier seulement la réaction à la métadonnée de l’archive et l’absence de
  cible.

## Critères de fin

- [ ] `extract-zip` a disparu de `apps/worker/package.json`, du code et de `bun.lock`.
- [ ] `yauzl` est utilisé comme lecteur, sans appel d’extraction globale.
- [ ] Chaque cible est résolue et prouvée sous le dossier temporaire avant ouverture.
- [ ] Les liens et types spéciaux sont rejetés ; aucun mode de l’archive n’est appliqué.
- [ ] Les écritures sont streaming et exclusives (`wx`).
- [ ] Les sept familles de tests de confinement passent.
- [ ] Les tests PRIM, tous les tests worker et le typecheck passent.
- [ ] `GHSA-jmr9-qjv8-65gv` n’apparaît plus dans l’audit de la résolution.
- [ ] La ligne `import-fountains` et toutes les modifications fountains préexistantes sont intactes.
- [ ] Aucun fichier hors périmètre n’est modifié, hormis le statut dans `plans/README.md`.

## Conditions STOP

Arrêter et remonter le problème si :

- le diff initial de `apps/worker/package.json` contient autre chose que l’ajout
  fountains connu ou une modification déjà intégrée par l’opérateur ;
- la version disponible de `yauzl` ou de ses types est dépréciée, incompatible
  avec Bun/TypeScript 6 ou porte un avis haute sévérité non corrigé ;
- la vraie archive IDFM contient des liens, types spéciaux ou chemins qui
  exigeraient d’affaiblir une règle de confinement ;
- l’importeur a désormais besoin de conserver permissions ou liens de l’archive ;
- une extraction correcte nécessite une commande système ou un binaire natif ;
- un test de confinement ne peut être écrit sans créer une cible hors d’un
  dossier temporaire contrôlé ;
- un test/typecheck échoue deux fois après correction raisonnable ;
- un fichier hors périmètre doit être modifié.

## Notes de maintenance

- La liste d’hôtes approuvés réduit la probabilité d’une archive hostile, mais
  ne remplace pas le confinement : CDN, compte fournisseur et chaîne de
  publication restent des frontières externes.
- En review, inspecter d’abord la normalisation Windows, le test du préfixe avec
  séparateur terminal et la gestion des bits Unix ; ce sont les endroits où une
  correction apparemment lisible laisse souvent une échappatoire.
- Toute future limite de taille ou de ratio de compression doit être calibrée
  sur plusieurs feeds IDFM réels et faire l’objet d’un plan séparé.
- Le script fountains n’appartient pas à cette migration. Un lockfile ou un
  manifeste régénéré ne doit jamais effacer du travail utilisateur adjacent.
