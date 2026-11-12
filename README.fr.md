# charigo

[![CI](https://github.com/wewesss/charigo/actions/workflows/ci.yml/badge.svg)](https://github.com/wewesss/charigo/actions/workflows/ci.yml) [![LuaRocks](https://img.shields.io/luarocks/v/SUP2Ak/charigo?color=blue)](https://luarocks.org/modules/SUP2Ak/charigo) [![release](https://img.shields.io/github/v/release/wewesss/charigo?color=blue)](https://github.com/wewesss/charigo/releases/latest) [![downloads](https://img.shields.io/github/downloads/wewesss/charigo/total?color=blue)](https://github.com/wewesss/charigo/releases) [![focus](https://img.shields.io/badge/focus-Charset%20Conversion-purple)](https://img.shields.io/badge/focus-Charset%20Conversion-purple) [![lang](https://img.shields.io/badge/lang-Lua%205.1%2B%20%2F%20LuaJIT-green)](https://img.shields.io/badge/lang-Lua%205.1%2B%20%2F%20LuaJIT-green) [![runtime deps](https://img.shields.io/badge/runtime%20deps-0-brightgreen)](https://img.shields.io/badge/runtime%20deps-0-brightgreen) [![license](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)

> "Conversion de jeux de caractères pour Lua : UTF-8 strict, politiques d'erreur explicites, aucune dépendance."

📖 [English](./README.md) · Français

[Encodages](./doc/fr.md#encodages) · [API](./doc/fr.md#api) · [Politiques d'erreur](./doc/fr.md#politiques-derreur) · [Détecter l'encodage du système](./doc/fr.md#détecter-lencodage-du-système) · [Migrer depuis map](./doc/fr.md#migrer-depuis-map)

---

## 🧠 C'est quoi charigo ?

Une bibliothèque de conversion de jeux de caractères pour Lua 5.1, 5.2, 5.3, 5.4 et LuaJIT. Lua pur, sans dépendance, sans état global.

- **Encodages** — UTF-8 (strict, RFC 3629), UTF-16LE, UTF-16BE, UTF-16 avec BOM, Latin-1 et CP1252.
- **Politiques d'erreur** — `strict` (par défaut, lève une erreur avec la position), `replace` et `skip`.
- **Détection de l'encodage du système** — `charigo.detect()` donne la page de code ANSI ou le jeu de caractères de la locale.

---

## ⚖️ Pourquoi charigo (et quand ne pas l'utiliser)

charigo est en Lua pur : un seul fichier ou cinq modules, sans compilateur C, sans libiconv, sans `ffi` obligatoire. Son intérêt est de tourner là où l'on ne peut pas charger de modules C : Lua embarqué ou en bac à sable (modding et scripting de jeux, hôtes de plugins, environnements restreints qui n'acceptent que des sources Lua).

**Si vous pouvez charger des modules C, utilisez lua-iconv.** Il est plus rapide (environ 2 à 5 fois sur les jeux à un octet, environ 8 à 11 fois sur UTF-16, mesuré dans [bench/RESULTS.md](./bench/RESULTS.md), en anglais) et il gère des centaines d'encodages. charigo ne battra pas le C.

Ce que charigo apporte en plus :

- Des erreurs avec la position et la cause (`invalid utf-8 at byte N`, `cannot encode U+20AC in latin1 at index N`), là où iconv renvoie un code et la sortie partielle.
- Les politiques `replace` (U+FFFD, ou `?` vers un jeu à un octet) et `skip`.
- Les octets non définis de CP1252 associés aux contrôles C1 (WHATWG), là où libiconv les refuse.
- `detect()` pour l'encodage du système.

Les deux refusent les surrogates, les formes trop longues et les séquences tronquées.

Ce qu'iconv a et que charigo n'a pas aujourd'hui : bien plus d'encodages, `//TRANSLIT`, et la conversion incrémentale (par morceaux).

---

## 🚀 Démarrage rapide

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

---

## 📦 Installation

**Via LuaRocks :**

```sh
luarocks install charigo
```

**Depuis la release GitHub** (sans LuaRocks) :

Téléchargez `charigo-vX.Y.Z.zip` depuis la [dernière release](https://github.com/wewesss/charigo/releases/latest). Elle contient `charigo.lua` (le bundle en un seul fichier), `LICENSE` et un court `README.md`.

```lua
-- 1. Posez charigo.lua sur votre package.path
local charigo = require("charigo")

-- 2. Ou chargez-le directement sans toucher au package.path
local charigo = dofile("chemin/vers/charigo.lua")
```

**Depuis les sources** (développement / contribution) :

```sh
git clone https://github.com/wewesss/charigo.git
cd charigo
lua build.lua              # → dist/charigo.lua (un seul fichier)
lua tests/run.lua          # contre les sources
lua tests/run.lua dist     # contre le bundle
```

Ou copiez le dossier `charigo/` (cinq modules : `init`, `utf8`, `sbcs`, `utf16`, `os`) dans votre `package.path`.

Testé sur **Lua 5.1, 5.2, 5.3, 5.4** et **LuaJIT 2.1** en CI (Linux). Zéro dépendance externe.

---

## 🔤 Encodages

Les noms ne sont pas sensibles à la casse.

| Nom canonique | Noms acceptés |
| --- | --- |
| UTF-8 | `utf-8`, `utf8` |
| UTF-16 petit-boutiste | `utf-16le`, `utf16le` |
| UTF-16 gros-boutiste | `utf-16be`, `utf16be` |
| UTF-16 avec BOM | `utf-16`, `utf16` |
| Latin-1 | `latin1`, `latin-1`, `iso-8859-1` |
| CP1252 | `cp1252`, `windows-1252` |

L'UTF-8 est strict, selon la RFC 3629 : les formes trop longues, les surrogates, les valeurs au-delà de U+10FFFF et les séquences tronquées sont invalides.

---

## 🛡️ Politiques d'erreur

Passez `{ errors = "..." }` en dernier argument.

| Politique | Entrée invalide (décodage) | Point de code invalide ou non représentable (encodage) |
| --- | --- | --- |
| `strict` (par défaut) | lève une erreur, avec la position | lève une erreur, avec l'indice |
| `replace` | un U+FFFD par unité fautive | U+FFFD en UTF-8 et UTF-16 ; `?` en Latin-1 et CP1252 |
| `skip` | l'unité fautive est supprimée | l'entrée est supprimée |

---

## 🔎 Détecter l'encodage du système

```lua
local enc, info = charigo.detect()
print(enc, info.source, info.os)
```

`enc` est un nom canonique utilisable avec les autres fonctions, ou `nil` quand l'encodage n'est pas détecté ou pas pris en charge. Sous Windows, il vient de `GetACP` par `ffi` sous LuaJIT, sinon du registre et de `chcp` ; sous POSIX, de `LC_ALL`, `LC_CTYPE` puis `LANG`. `detect()` ne lève jamais d'erreur.

---

## 🛠️ Build et tests

```sh
lua build.lua                # → dist/charigo.lua (un seul fichier autonome)
lua tests/run.lua            # suite de tests contre les sources
lua tests/run.lua dist       # même suite contre le bundle
```

## ⚡ Performance

charigo choisit son chemin rapide selon l'environnement. Sur Lua PUC, UTF-8 vers Latin-1, CP1252 et UTF-16, et UTF-16 vers UTF-8, passent par `gsub` sur une table, et sur Lua 5.4 `valid` appelle d'abord le `utf8.len` natif. Sur LuaJIT, les boucles simples restent, avec seulement un raccourci pour l'ASCII.

Mesures locales sur Lua 5.4, avant et après : `valid` sur du texte français de 38 à 876 Mo/s, UTF-8 vers CP1252 sur de l'ASCII de 15 à 137 Mo/s, UTF-8 vers UTF-16LE sur du texte français de 7 à 26 Mo/s, UTF-16LE vers UTF-8 sur du texte français de 16 à 74 Mo/s. Sur LuaJIT, UTF-8 vers CP1252 sur de l'ASCII passe de 44 à 251 Mo/s.

Ce sont les chiffres d'une seule machine, pas de la CI. Les tableaux complets, les commandes et la comparaison avec la bibliothèque `utf8` native, lua-iconv et l'API Win32 sont dans [bench/RESULTS.md](./bench/RESULTS.md) (en anglais).

## 📊 Benchmark

```sh
lua bench/run.lua            # exécution complète
lua bench/run.lua --smoke    # exécution courte, utilisée en CI
```

L'exécution smoke en CI vérifie seulement que le script tourne sur chaque environnement ; ses chiffres ne veulent rien dire.

---

## 🔁 Migrer depuis `map`

L'ancien module `lua-charset-converter` (`map.lua`, v1.0.0) est supprimé en 2.0.0. La correspondance entre les anciens appels et les nouveaux est dans le [CHANGELOG](./CHANGELOG.md) (en anglais).

---

## ❤️ Soutien

Si charigo vous aide :

👉 [Star le repo](https://github.com/wewesss/charigo) · [Ouvrir une issue](https://github.com/wewesss/charigo/issues)

---

## 📜 Licence

[**MIT**](./LICENSE) — Copyright (c) 2026 Wesley Cormier (SUP2Ak).
