# charigo

[![CI](https://github.com/wewesss/charigo/actions/workflows/ci.yml/badge.svg)](https://github.com/wewesss/charigo/actions/workflows/ci.yml) [![LuaRocks](https://img.shields.io/luarocks/v/SUP2Ak/charigo?color=blue)](https://luarocks.org/modules/SUP2Ak/charigo) [![release](https://img.shields.io/github/v/release/wewesss/charigo?color=blue)](https://github.com/wewesss/charigo/releases/latest) [![focus](https://img.shields.io/badge/focus-Charset%20Conversion-purple)](https://img.shields.io/badge/focus-Charset%20Conversion-purple) [![lang](https://img.shields.io/badge/lang-Lua%205.1%2B%20%2F%20LuaJIT-green)](https://img.shields.io/badge/lang-Lua%205.1%2B%20%2F%20LuaJIT-green) [![runtime deps](https://img.shields.io/badge/runtime%20deps-0-brightgreen)](https://img.shields.io/badge/runtime%20deps-0-brightgreen) [![license](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)

> "Character set conversion for Lua: strict UTF-8, explicit error policies, no dependency."

📖 English · [Français](./README.fr.md)

[Encodings](./doc/en.md#encodings) · [API](./doc/en.md#api) · [Error policies](./doc/en.md#error-policies) · [Detecting the system encoding](./doc/en.md#detecting-the-system-encoding) · [Migrating from map](./doc/en.md#migrating-from-map)

---

## 🧠 What is charigo?

A character set conversion library for Lua 5.1, 5.2, 5.3, 5.4 and LuaJIT. Pure Lua, no dependency, no global state.

- **Encodings** — UTF-8 (strict RFC 3629), UTF-16LE, UTF-16BE, UTF-16 with BOM, Latin-1 and CP1252.
- **Error policies** — `strict` (default, raises with the position), `replace` and `skip`.
- **System encoding detection** — `charigo.detect()` tells you the ANSI code page or the locale charset.

---

## 🚀 Quickstart

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

Errors are raised with `error(message, 0)`: the message has no file or line prefix. Catch them with `pcall`.

---

## 📦 Install

**Via LuaRocks:**

```sh
luarocks install charigo
```

**From the GitHub release** (no LuaRocks):

Download `charigo-vX.Y.Z.zip` from the [latest release](https://github.com/wewesss/charigo/releases/latest). It holds `charigo.lua` (the single-file bundle), `LICENSE` and a short `README.md`.

```lua
-- 1. Put charigo.lua on your package.path
local charigo = require("charigo")

-- 2. Or load it directly without touching package.path
local charigo = dofile("path/to/charigo.lua")
```

**From source** (development / contribution):

```sh
git clone https://github.com/wewesss/charigo.git
cd charigo
lua build.lua              # → dist/charigo.lua (single file)
lua tests/run.lua          # against the source tree
lua tests/run.lua dist     # against the bundle
```

Or copy the `charigo/` folder (five modules: `init`, `utf8`, `sbcs`, `utf16`, `os`) onto your `package.path`.

Tested on **Lua 5.1, 5.2, 5.3, 5.4** and **LuaJIT 2.1** in CI (Linux). Zero external dependencies.

---

## 🔤 Encodings

Names are case-insensitive.

| Canonical name | Accepted names |
| --- | --- |
| UTF-8 | `utf-8`, `utf8` |
| UTF-16 little endian | `utf-16le`, `utf16le` |
| UTF-16 big endian | `utf-16be`, `utf16be` |
| UTF-16 with BOM | `utf-16`, `utf16` |
| Latin-1 | `latin1`, `latin-1`, `iso-8859-1` |
| CP1252 | `cp1252`, `windows-1252` |

UTF-8 is strict RFC 3629: overlong forms, surrogates, values above U+10FFFF and truncated sequences are invalid.

---

## 🛡️ Error policies

Pass `{ errors = "..." }` as the last argument.

| Policy | Invalid input (decoding) | Unmappable or invalid code point (encoding) |
| --- | --- | --- |
| `strict` (default) | raises, with the position | raises, with the index |
| `replace` | one U+FFFD per bad unit | U+FFFD in UTF-8 and UTF-16; `?` in Latin-1 and CP1252 |
| `skip` | the bad unit is dropped | the entry is dropped |

---

## 🔎 Detecting the system encoding

```lua
local enc, info = charigo.detect()
print(enc, info.source, info.os)
```

`enc` is a canonical name usable with the other functions, or `nil` when the encoding is not detected or not supported. On Windows it comes from `GetACP` through `ffi` under LuaJIT, otherwise from the registry and `chcp`; on POSIX from `LC_ALL`, `LC_CTYPE` then `LANG`. `detect()` never raises.

---

## 🛠️ Build & tests

```sh
lua build.lua                # → dist/charigo.lua (single self-contained file)
lua tests/run.lua            # run the test suite against the source tree
lua tests/run.lua dist       # same suite against the bundle
```

## 📊 Benchmark

```sh
lua bench/run.lua            # full run
lua bench/run.lua --smoke    # short run, used in CI
```

The CI smoke run only checks that the script works on every runtime; its numbers mean nothing.

---

## 🔁 Migrating from `map`

The old `lua-charset-converter` module (`map.lua`, v1.0.0) is removed in 2.0.0. The mapping from the old calls to the new ones is in the [CHANGELOG](./CHANGELOG.md).

---

## ❤️ Support

If charigo helps you:

👉 [Star the repo](https://github.com/wewesss/charigo) · [Open an issue](https://github.com/wewesss/charigo/issues)

---

## 📜 License

[**MIT**](./LICENSE) — Copyright (c) 2026 Wesley Cormier (SUP2Ak).
