# Métadonnées optimisées — Metyro, fr-FR, v1.0

Champs prêts à poser. Les valeurs recommandées sont **déjà écrites** dans
`apps/via/metadata/` et passent `asc metadata validate` (0 erreur, 0 avertissement).
Elles ne sont **pas** encore poussées sur App Store Connect.

---

## Avant / après

| Champ | Avant | Après | Gain |
|---|---|---|---|
| Nom | `Metyro` (6/30) | `Metyro : Métro Paris, RER, Bus` (30/30) | +4 mots-clés indexés dans le champ le plus pondéré |
| Sous-titre | `Métro Paris en temps réel` (25/30) | `Horaires et trafic temps réel` (29/30) | ne double plus le nom : +3 mots-clés nets |
| Mots-clés | 12 termes, 5 hors intention (96/100) | 14 termes, tous ciblés (99/100) | +6 familles de requêtes, −5 impasses |
| Texte promotionnel | résumé de fonctionnalités (162/170) | accroche produit (162/170) | conversion |
| Description | 1 743/4 000, accroche en sommaire | 1 901/4 000, accroche en scène | +Transilien, +Vélib’, +toilettes |

---

## Nom (30 caractères)

### ✅ Recommandé — `Metyro : Métro Paris, RER, Bus` — 30/30

Mots-clés couverts : `metyro`, `métro`, `paris`, `rer`, `bus`
Requêtes visées : `métro paris`, `métro paris rer`, `bus paris`, `rer paris`, `metro rer paris`

Pourquoi celui-ci. Il applique la convention exacte de la catégorie sur le store FR
(`Tisséo : Métro, Tram, Bus`, `Moovit: Transports en commun`, `Transit • Horaires Bus &
Métro`), il garde la marque en tête — Metyro reste le nom, ce n'est pas un titre
générique — et il remplit les 30 caractères. Il pose les quatre tokens qui, combinés au
sous-titre et au champ mots-clés, débloquent l'essentiel des familles de requêtes du marché.

### Alternative A — `Metyro : Métro Paris & RER` — 26/30

Plus resserré, colle au titre n°1 du marché (`Métro Paris & RER`, 13 914 avis, premier sur
`metro paris`). Abandonne `bus` : à reprendre alors dans le champ mots-clés, où il coûte
4 caractères et se combine moins bien.

### Alternative B — `Metyro : Métro, RER, Bus, Tram` — 30/30

Ajoute `tram`, retire `paris`. À écarter : `paris` est le qualificatif qui transforme des
mots génériques en requêtes locales, et `tram` seul renvoie, sur l'App Store FR,
Montpellier, Bordeaux, Strasbourg, Nice et Nantes. Mauvais échange.

---

## Sous-titre (30 caractères)

### ✅ Recommandé — `Horaires et trafic temps réel` — 29/30

Mots-clés couverts : `horaire`, `trafic`, `temps`, `réel`
Requêtes débloquées par combinaison avec le nom : `horaire métro`, `horaire bus`,
`horaire rer`, `trafic métro`, `trafic rer`, `bus temps réel`, `info trafic`

Pourquoi celui-ci. Le sous-titre actuel (`Métro Paris en temps réel`) répète `Métro` et
`Paris`, qui passent désormais dans le nom : c'est 11 caractères pour zéro token
supplémentaire. Cette version les remplace par quatre tokens neufs, et garde la promesse
produit — le temps réel — lisible pour l'humain qui lit sous le nom de l'app.

Elle règle aussi le piège documenté dans la recherche : `trafic` isolé dans le champ
mots-clés attire des jeux de course ; dans le sous-titre, il se combine avec le `Métro` du
nom et devient `trafic métro`, une vraie requête.

### Alternative A — `Horaires, trafic, Transilien` — 28/30

Récupère `transilien` (2ᵉ opportunité du tableau) dans un champ plus pondéré que les
mots-clés, mais sacrifie `temps réel`, qui est la promesse de l'app et sa différence.
À retenir si l'on veut pousser Transilien fort ; libère alors 11 caractères de mots-clés.

### Alternative B — `Prochains passages et trafic` — 28/30

Positionnement le plus proche de l'usage réel, et `prochain passage` est une requête de
faible difficulté. Mais `passages` au pluriel et `prochains` sont déjà couverts par le champ
mots-clés pour 16 caractères, alors que `temps réel` ne l'est pas.

---

## Champ mots-clés (100 caractères)

### ✅ Recommandé — 99/100

```
transilien,tram,idf,ile,france,transport,commun,plan,ligne,station,prochain,passage,itineraire,gare
```

| Token | Car. | Pourquoi |
|---|---|---|
| `transilien` | 10 | 2ᵉ opportunité du marché, réseau réellement couvert, peu disputé |
| `tram` | 4 | mode réellement couvert ; ne paie qu'en combinaison avec `paris` (nom) |
| `idf` | 3 | `idf transport`, `idf mobilite` — trois caractères, forte demande |
| `ile` + `france` | 10 | couvre `ile de france` ; 3 caractères de moins que `ile-de-france`, index identique |
| `transport` | 9 | `transport ile de france` est la 1ʳᵉ suggestion Apple sur `transport` |
| `commun` | 6 | débloque `transport en commun paris` |
| `plan` | 4 | débloque toute la famille `plan métro paris` |
| `ligne` | 5 | `ligne métro`, `ligne rer`, `trafic ligne` |
| `station` | 7 | `station métro`, `station rer` |
| `prochain` | 8 | `prochain metro` — 4 résultats en tout sur le store, à prendre |
| `passage` | 7 | `prochain passage`, `horaire passage` |
| `itineraire` | 10 | conservé malgré une intention majoritairement vélo/voiture : c'est le mot que tape l'usager transport qui ne connaît pas le jargon, et il se combine (`itineraire métro`, `itineraire paris`) |
| `gare` | 4 | `gare` + `paris`/`rer` ; couvre l'usager Transilien |

Sortis par rapport à l'existant : `trafic` (remonté au sous-titre), `horaires` (remonté au
sous-titre), `rer` et `bus` (remontés au nom), `navigation` (intention GPS routier),
`perturbation` (12 caractères pour une requête que `trafic` couvre déjà par combinaison).

Sans accents et au singulier : Apple normalise les diacritiques et les pluriels, et les
utilisateurs tapent majoritairement sans accent.

### Alternative A — remplacer `gare` par `velib` (100/100)

```
transilien,tram,idf,ile,france,transport,commun,plan,ligne,station,prochain,passage,itineraire,velib
```

Vélib’ est réellement intégré (stations, capacité, vélos disponibles) et `velib paris` a de
la demande. Mais c'est une marque déposée : voir l'arbitrage dans `02-keyword-research.md`.

### Alternative B — si le sous-titre passe à l'alternative A (`…Transilien`)

`transilien` sort du champ et libère 11 caractères :

```
tram,idf,ile,france,transport,commun,plan,ligne,station,prochain,passage,itineraire,gare,direct,velo
```

---

## Matrice de couverture

| Requête | Nom | Sous-titre | Mots-clés | Couverte ? |
|---|:--:|:--:|:--:|---|
| métro paris | ✓ ✓ | | | ✅ un seul champ |
| métro paris rer | ✓ ✓ ✓ | | | ✅ un seul champ |
| bus paris | ✓ ✓ | | | ✅ un seul champ |
| plan métro paris | ✓ ✓ | | ✓ | ✅ combinaison |
| horaire bus | ✓ | ✓ | | ✅ combinaison |
| horaire métro | ✓ | ✓ | | ✅ combinaison |
| trafic métro | ✓ | ✓ | | ✅ combinaison |
| bus temps réel | ✓ | ✓ ✓ | | ✅ combinaison |
| info trafic | | ✓ | | ⚠️ partiel — `info` non présent |
| transilien | | | ✓ | ✅ |
| prochain métro | ✓ | | ✓ | ✅ combinaison |
| prochain passage | | | ✓ ✓ | ✅ |
| station métro | ✓ | | ✓ | ✅ combinaison |
| ligne métro | ✓ | | ✓ | ✅ combinaison |
| transport ile de france | | | ✓ ✓ ✓ | ✅ |
| transport en commun paris | ✓ | | ✓ ✓ | ✅ combinaison |
| idf transport | | | ✓ ✓ | ✅ |
| rer b / rer a / rer d | ✓ | | | ❌ lettres de ligne non couvrables |
| ratp / navigo | | | | ❌ marque tierce, écartée sciemment |

---

## Texte promotionnel (170 caractères)

### ✅ Recommandé — 162/170

> Le prochain métro passe dans 3 minutes — Metyro vous le dit avant que vous ayez descendu
> l’escalier. Métro, RER, Transilien, tram, bus et Vélib’ en Île-de-France.

Non indexé par Apple, mais c'est la première ligne au-dessus de la description, et il se
change **sans passer par la review**. Le précédent texte redisait la liste des
fonctionnalités que la description reprend juste en dessous. Celui-ci pose une scène et
laisse la description faire l'inventaire.

Usages ultérieurs, sans review : rentrée de septembre, grèves, JO, ouverture d'une nouvelle
ville, mention presse.

---

## Description (4 000 caractères) — 1 901

Trois changements par rapport à l'existant, le reste du texte est conservé — il était bon.

**1. L'accroche.** Les 170 premiers caractères sont tout ce qui s'affiche avant « plus ».

Avant — un sommaire :
> Metyro réunit tout ce qu’il faut pour vos trajets en Île-de-France : itinéraires,
> prochains passages, perturbations et suivi en direct, dans une app claire et immédiate.

Après — une scène, et la promesse qui la suit :
> Le prochain métro passe dans 3 minutes. Metyro vous le dit avant que vous ayez fini de
> descendre l’escalier — et si la ligne est perturbée, il vous dit par où passer.

**2. Trois fonctionnalités livrées mais jamais vendues.** Vérifiées dans le code :
- **Transilien** — le mode est modélisé dans `Features/Network`, la description ne le citait pas
- **Vélib’** — `BikeStationDTO` porte capacité et disponibilité, la carte a sa couche dédiée
- **Toilettes en station** — `StationDetailView`, à côté des ascenseurs et du plain-pied

**3. La section accessibilité gagne les toilettes**, et la section carte gagne Vélib’.

Le texte complet est dans `apps/via/metadata/version/1.0/fr-FR.json`.

---

## Poser les changements

Les fichiers locaux sont déjà à jour et validés. Pour les envoyer sur App Store Connect :

```bash
# 1. Plan de modification, sans rien écrire
asc metadata push --app 6801259695 --version 1.0 --platform IOS \
  --dir ./apps/via/metadata --dry-run --output table

# 2. Appliquer
asc metadata push --app 6801259695 --version 1.0 --platform IOS \
  --dir ./apps/via/metadata
```

Le nom et le sous-titre passent par la review App Store. Le texte promotionnel, non.

---

## Ce que ces champs ne règlent pas

Les métadonnées valent 50 % du score ASO. Le reste ne se corrige pas en JSON :

1. **Aucune capture** — bloque la soumission *et* pèse 15 % du classement. Premier chantier.
2. **Aucun build attaché, pas de coordonnées de review, App Privacy à publier** —
   `asc validate --app 6801259695 --version 1.0` remonte les trois.
3. **Catégories non renseignées** sur l'app-info.
4. **Zéro avis** — structurel, mais une invitation à noter posée au bon moment se prépare
   maintenant, pas après.
