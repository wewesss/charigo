# charigo

Conversion de jeux de caractères pour Lua 5.1, 5.2, 5.3, 5.4 et LuaJIT. Lua pur, sans dépendance, sans état global.

Version 1.0.0. Version anglaise : [en.md](./en.md).

## Installation

Avec LuaRocks :

```
luarocks install charigo
```

Sans LuaRocks, deux possibilités : copier le dossier `charigo/` (cinq modules : `init`, `utf8`, `sbcs`, `utf16`, `os`) dans votre `package.path`, ou copier le bundle en un seul fichier. Le bundle est généré à partir des sources et n'est pas versionné :

```
lua build.lua
```

La commande écrit `dist/charigo.lua`. Placez-le dans votre projet, puis `local charigo = require("charigo")` (ou `dofile`). Tests : `lua tests/run.lua` sur les sources, `lua tests/run.lua dist` sur le bundle.

## Démarrage rapide

```lua
local charigo = require("charigo")

local utf8 = charigo.convert("caf\233 \128", "cp1252", "utf-8")
print(utf8)

local latin = charigo.convert("caf\195\169", "utf-8", "latin1")

local cps = charigo.decode("h\195\169", "utf-8")
print(cps[1], cps[2])
print(charigo.encode({ 0x68, 0xE9 }, "utf-16le"))

print(charigo.valid("\255", "utf-8"))

local ok, err = pcall(charigo.convert, "\226\130\172", "utf-8", "latin1")
print(ok, err)

local lossy = charigo.convert("\226\130\172", "utf-8", "latin1", { errors = "replace" })

local to1252 = charigo.converter("utf-8", "cp1252")
print(to1252("na\195\175ve"))

print(charigo.detect())
```

Les erreurs sont levées avec `error(message, 0)` : le message n'a ni fichier ni numéro de ligne en préfixe. Attrapez-les avec `pcall`.

## Encodages

Les noms ne sont pas sensibles à la casse.

| Nom canonique | Noms acceptés |
| --- | --- |
| UTF-8 | `utf-8`, `utf8` |
| UTF-16 petit-boutiste | `utf-16le`, `utf16le` |
| UTF-16 gros-boutiste | `utf-16be`, `utf16be` |
| UTF-16 avec BOM | `utf-16`, `utf16` |
| Latin-1 | `latin1`, `latin-1`, `iso-8859-1` |
| CP1252 | `cp1252`, `windows-1252` |

Un nom inconnu (ou qui n'est pas une chaîne) lève `charigo: unknown encoding '<nom>'`.

L'UTF-8 est strict, selon la RFC 3629 : les formes trop longues, les surrogates (U+D800 à U+DFFF), les valeurs au-delà de U+10FFFF et les séquences tronquées sont invalides.

## API

Les chaînes sont des chaînes d'octets. Les « points de code » sont des tableaux d'entiers de 0 à 0x10FFFF, surrogates exclus.

### `charigo.convert(s, from, to [, opts]) -> string`

Convertit `s` de l'encodage `from` vers l'encodage `to`. Les convertisseurs sont construits au premier appel et mis en cache selon `(from, to, errors, bom)`.

```lua
charigo.convert("\233", "latin1", "utf-8")
```

### `charigo.converter(from, to [, opts]) -> function`

Renvoie une fonction `fn(s) -> string` qui fait la même conversion que `convert`, sans recherche à chaque appel. Les noms et `opts` sont vérifiés à la création : un encodage ou une politique inconnus lèvent l'erreur ici, pas au premier appel.

### `charigo.decode(s, enc [, opts]) -> table`

Décode `s` en un tableau de points de code. Seule `opts.errors` est lue. Pour `latin1` et `cp1252`, tous les octets se décodent (voir la section CP1252) : aucune erreur n'est possible.

### `charigo.encode(cps, enc [, opts]) -> string`

Encode un tableau de points de code. Lit `opts.errors` et `opts.bom`. Une entrée est invalide si ce n'est pas un nombre entier, si elle est négative, si elle dépasse 0x10FFFF ou si c'est un surrogate.

### `charigo.valid(s, enc) -> boolean [, position]`

Renvoie `true` si `s` est valide dans `enc`, sinon `false` et la position (à partir de 1, en octets) du premier problème (UTF-8 : premier octet de la séquence fautive ; UTF-16 : premier octet de l'unité fautive, ou dernier octet isolé). Ne lève jamais d'erreur sur le contenu, seulement sur un encodage inconnu. `latin1` et `cp1252` sont toujours valides.

### `charigo.detect() -> enc, info`

Voir [Détecter l'encodage du système](#détecter-lencodage-du-système).

### `charigo._VERSION`

La chaîne `"1.0.0"`. `charigo._sbcs` et `charigo._os` sont internes et n'existent que pour les tests.

### Options

| Champ | Valeurs | Défaut | Rôle |
| --- | --- | --- | --- |
| `errors` | `"strict"`, `"replace"`, `"skip"` | `"strict"` | Politique d'erreur. Toute autre valeur lève `charigo: unknown errors policy '<valeur>'`. |
| `bom` | `true` | désactivé | Écrit une marque d'ordre des octets en encodant vers `utf-16le` ou `utf-16be`. Ignoré pour les autres cibles. |

`opts` peut être omis ou valoir `nil`.

### Messages d'erreur

Tous les messages commencent par `charigo: `. Ils restent en anglais, quelle que soit la langue de la documentation, pour rester stables et faciles à rechercher.

| Message | Cas |
| --- | --- |
| `charigo: invalid utf-8 at byte N` | Décodage UTF-8 en mode strict. `N` commence à 1. |
| `charigo: invalid utf-16 at byte N` | Décodage UTF-16 en mode strict : surrogate isolé ou mal ordonné, ou octet final en trop. |
| `charigo: invalid code point at index N` | Encodage strict (toute cible) d'une entrée invalide. `N` est l'indice, à partir de 1, dans le tableau. |
| `charigo: cannot encode U+XXXX in latin1 at index N` | Encodage strict d'un point de code valide que le jeu ne peut pas représenter. Le nom est `latin1` ou `cp1252`. |
| `charigo: unknown encoding '<nom>'` | Nom d'encodage incorrect. |
| `charigo: unknown errors policy '<valeur>'` | `opts.errors` incorrect. |

## Politiques d'erreur

| Politique | Entrée invalide (décodage) | Point de code invalide ou non représentable (encodage) |
| --- | --- | --- |
| `strict` | lève une erreur, avec la position | lève une erreur, avec l'indice |
| `replace` | un U+FFFD par unité fautive | U+FFFD en UTF-8 et UTF-16 ; `?` (0x3F) en Latin-1 et CP1252 |
| `skip` | l'unité fautive est supprimée | l'entrée est supprimée |

Dans une conversion, les deux étapes utilisent la même politique. Par exemple `convert("\255", "utf-8", "latin1", { errors = "replace" })` donne `"?"` (l'octet invalide devient U+FFFD, que le Latin-1 ne peut pas représenter). Avec `replace` et `skip`, un résultat UTF-8 ou UTF-16 est toujours valide.

Convertir un jeu vers lui-même en mode `strict` (`utf-8` vers `utf-8`, `latin1` vers `latin1`) renvoie l'entrée telle quelle après validation.

## UTF-16 et BOM

- `utf-16le` et `utf-16be` ont un ordre d'octets fixe.
- `utf-16` écrit toujours un BOM (`FF FE`, puis petit-boutiste) et, en lecture, prend l'ordre indiqué par le BOM.
- En lecture, un BOM en tête est consommé et n'apparaît jamais dans le résultat. `utf-16` accepte `FF FE` (petit-boutiste) et `FE FF` (gros-boutiste) ; sans BOM, il lit en petit-boutiste. `utf-16le` ne consomme que `FF FE`, `utf-16be` que `FE FF` ; l'autre marque est lue comme une donnée (U+FFFE).
- En écriture avec `utf-16le` ou `utf-16be` : pas de BOM, sauf si `opts.bom = true`.
- `opts.bom` n'a aucun effet au décodage, ni quand la cible n'est pas de l'UTF-16.
- Une paire de surrogates est recomposée en un seul point de code au-delà de U+FFFF ; un surrogate isolé est invalide.

## CP1252 et les octets non définis

La CP1252 laisse cinq octets non définis : 0x81, 0x8D, 0x8F, 0x90 et 0x9D. charigo suit la norme WHATWG Encoding (windows-1252) et les associe aux caractères de contrôle C1 de même valeur : U+0081, U+008D, U+008F, U+0090, U+009D. Conséquences :

- Tous les octets de 0x00 à 0xFF se décodent : décoder de la CP1252 n'échoue jamais.
- La correspondance est une bijection : `cp1252 -> utf-8 -> cp1252` redonne les octets d'origine.
- Encoder U+0081, U+008D, U+008F, U+0090 ou U+009D en CP1252 redonne ces octets.
- Les 27 autres octets de 0x80 à 0x9F suivent la table de Microsoft (par exemple 0x80 vaut U+20AC, le symbole euro).

C'est un choix, pas la seule option possible : le codec `cp1252` de Python rejette ces cinq octets. charigo ne le fait pas.

Le Latin-1 associe chaque octet au point de code de même valeur.

## Détecter l'encodage du système

```lua
local enc, info = charigo.detect()
```

`enc` est un nom canonique utilisable avec les autres fonctions (`"utf-8"`, `"cp1252"`, `"latin1"`, `"utf-16le"`, `"utf-16be"`), ou `nil` quand l'encodage n'est pas détecté ou pas pris en charge. `info` est toujours une table :

| Champ | Signification |
| --- | --- |
| `source` | D'où vient la réponse : `"ffi"`, `"reg"`, `"chcp"`, `"env"` ou `"none"`. |
| `os` | `"windows"` ou `"posix"`. |
| `codepage` | Windows : numéro de la page de code ANSI (encodage du système). |
| `console_codepage` | Windows : numéro de la page de code de sortie de la console. |
| `console` | Nom canonique de l'encodage de la console, quand il est connu. Sous POSIX, identique à `enc`. |
| `raw` | La valeur brute lue : le numéro de page de code sous forme de texte sous Windows, la chaîne de la locale sous POSIX. |

Windows :

1. `"ffi"` : sous LuaJIT, `GetACP` et `GetConsoleOutputCP` par `ffi`. `enc` correspond à la page de code ANSI.
2. `"reg"` : sans `ffi`, la page de code ANSI est lue dans le registre avec `reg query` par `io.popen`, et celle de la console avec `chcp`.
3. `"chcp"` : si la lecture du registre échoue, seul `chcp` répond. `enc` vaut alors `nil` et `codepage` est absent, mais `console_codepage` et `console` sont renseignés.
4. `"none"` : rien n'a pu être lu.

Pages de code connues : 65001 (utf-8), 1252 (cp1252), 28591 (latin1), 1200 (utf-16le), 1201 (utf-16be). Tout autre numéro laisse `enc` (ou `console`) à `nil` ; consultez alors `info.codepage`.

POSIX : on prend la première variable non vide parmi `LC_ALL`, `LC_CTYPE`, `LANG` (`source = "env"`, `raw` contient sa valeur). Le jeu de caractères placé après le point (`fr_FR.UTF-8`, `de_DE.ISO-8859-1@euro`) est comparé, sans tenir compte de la casse, des tirets ni des soulignés, à `utf8`, `iso88591`, `latin1`, `cp1252`, `windows1252`. Une locale comme `C` ou `POSIX` n'a pas de jeu de caractères : `enc` vaut `nil`. Si aucune des trois variables n'est définie, `source = "none"`.

`detect()` ne lève jamais d'erreur. Sous Windows sans `ffi`, elle lance des commandes externes (`reg`, `chcp`) avec `io.popen`.

## Environnements pris en charge

Lua 5.1, 5.2, 5.3, 5.4 et LuaJIT 2.1. La suite de tests et le bundle tournent sur chacun en CI (Linux). La branche Windows de `detect()` n'est pas exécutée en CI et se vérifie à la main.

## Interopérabilité avec zigo

[zigo](https://github.com/wewesss/zigo) valide les données à la frontière. Normalisez d'abord l'encodage, puis validez :

```lua
local charigo = require("charigo")
local z = require("zigo")

local name = z.utf8():min(1):max(32)

local function readName(raw, from)
    return name:parse(charigo.convert(raw, from, "utf-8"))
end

print(readName("Ren\233", "cp1252"))
```

`charigo.convert` lève une erreur si l'entrée ne peut pas être convertie ; `z.utf8()` vérifie ensuite les règles de longueur sur de l'UTF-8 bien formé.

## Migrer depuis `map`

L'ancien module `lua-charset-converter` (`map.lua`) est supprimé. Voir la section de migration du [changelog](../CHANGELOG.md).
