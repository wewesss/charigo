# charigo

Character set conversion for Lua 5.1, 5.2, 5.3, 5.4 and LuaJIT. Pure Lua, no dependency, no global state.

Version 2.0.0. French version: [fr.md](./fr.md).

## Install

With LuaRocks:

```
luarocks install charigo
```

From a GitHub release: download `charigo-vX.Y.Z.zip` from the [latest release](https://github.com/wewesss/charigo/releases/latest). It holds `charigo.lua` (the single-file bundle), `LICENSE` and a short `README.md`. Put `charigo.lua` on your `package.path`, or load it with `dofile`.

From source, either copy the `charigo/` folder (five modules: `init`, `utf8`, `sbcs`, `utf16`, `os`) onto your `package.path`, or copy the single-file bundle. The bundle is built from the sources and is not committed:

```
lua build.lua
```

This writes `dist/charigo.lua`. Drop it in your project and `local charigo = require("charigo")` (or `dofile`). Tests: `lua tests/run.lua` against the sources, `lua tests/run.lua dist` against the bundle.

## Quick start

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

## Encodings

Names are case-insensitive.

| Canonical name | Accepted names |
| --- | --- |
| UTF-8 | `utf-8`, `utf8` |
| UTF-16 little endian | `utf-16le`, `utf16le` |
| UTF-16 big endian | `utf-16be`, `utf16be` |
| UTF-16 with BOM | `utf-16`, `utf16` |
| Latin-1 | `latin1`, `latin-1`, `iso-8859-1` |
| CP1252 | `cp1252`, `windows-1252` |

An unknown name (or a non-string) raises `charigo: unknown encoding '<name>'`.

UTF-8 is strict RFC 3629: overlong forms, surrogates (U+D800 to U+DFFF), values above U+10FFFF and truncated sequences are invalid.

## API

Strings are byte strings. "Code points" are arrays of integers from 0 to 0x10FFFF, excluding surrogates.

### `charigo.convert(s, from, to [, opts]) -> string`

Converts `s` from encoding `from` to encoding `to`. Converters are built on first use and cached by `(from, to, errors, bom)`.

```lua
charigo.convert("\233", "latin1", "utf-8")
```

### `charigo.converter(from, to [, opts]) -> function`

Returns a function `fn(s) -> string` doing the same conversion as `convert`, with no per-call lookup. Names and `opts` are validated when the converter is created: an unknown encoding or policy raises there, not on the first call.

### `charigo.decode(s, enc [, opts]) -> table`

Decodes `s` into an array of code points. Only `opts.errors` is read. For `latin1` and `cp1252` every byte decodes (see the CP1252 section), so no error can occur.

### `charigo.encode(cps, enc [, opts]) -> string`

Encodes an array of code points. Reads `opts.errors` and `opts.bom`. An entry is invalid when it is not an integer number, is negative, is above 0x10FFFF or is a surrogate.

### `charigo.valid(s, enc) -> boolean [, position]`

Returns `true` when `s` is valid in `enc`, else `false` and the 1-based byte position of the first problem (UTF-8: first byte of the bad sequence; UTF-16: first byte of the bad unit, or the dangling last byte). Never raises on bad content, only on an unknown encoding. `latin1` and `cp1252` are always valid.

### `charigo.detect() -> enc, info`

See [Detecting the system encoding](#detecting-the-system-encoding).

### `charigo._VERSION`

The string `"2.0.0"`. `charigo._sbcs` and `charigo._os` are internal and exist for the tests only.

### Options

| Field | Values | Default | Meaning |
| --- | --- | --- | --- |
| `errors` | `"strict"`, `"replace"`, `"skip"` | `"strict"` | Error policy. Any other value raises `charigo: unknown errors policy '<value>'`. |
| `bom` | `true` | off | Write a byte order mark when encoding to `utf-16le` or `utf-16be`. Ignored for other targets. |

`opts` may be omitted or `nil`.

### Error messages

All messages start with `charigo: `.

| Message | When |
| --- | --- |
| `charigo: invalid utf-8 at byte N` | Strict decoding of UTF-8. `N` is 1-based. |
| `charigo: invalid utf-16 at byte N` | Strict decoding of UTF-16: lone or misordered surrogate, or an odd trailing byte. |
| `charigo: invalid code point at index N` | Strict encoding (any target) of an invalid entry. `N` is the 1-based index in the array. |
| `charigo: cannot encode U+XXXX in latin1 at index N` | Strict encoding of a valid code point the set cannot hold. The name is `latin1` or `cp1252`. |
| `charigo: unknown encoding '<name>'` | Bad encoding name. |
| `charigo: unknown errors policy '<value>'` | Bad `opts.errors`. |

## Error policies

| Policy | Invalid input (decoding) | Unmappable or invalid code point (encoding) |
| --- | --- | --- |
| `strict` | raises, with the position | raises, with the index |
| `replace` | one U+FFFD per bad unit | U+FFFD in UTF-8 and UTF-16; `?` (0x3F) in Latin-1 and CP1252 |
| `skip` | the bad unit is dropped | the entry is dropped |

When converting, both steps use the same policy. For example `convert("\255", "utf-8", "latin1", { errors = "replace" })` gives `"?"` (the bad byte becomes U+FFFD, which Latin-1 cannot hold). In `replace` and `skip` a UTF-8 or UTF-16 result is always valid.

Converting from a set to itself in `strict` mode (`utf-8` to `utf-8`, `latin1` to `latin1`) returns the input unchanged after validation.

## UTF-16 and the BOM

- `utf-16le` and `utf-16be` have a fixed byte order.
- `utf-16` writes a BOM (`FF FE`, then little endian) every time, and on reading takes the order from the BOM.
- Reading: a leading BOM is consumed and never appears in the result. `utf-16` accepts `FF FE` (little endian) and `FE FF` (big endian); with no BOM it reads little endian. `utf-16le` consumes only `FF FE`, `utf-16be` only `FE FF`; the other mark is read as data (U+FFFE).
- Writing with `utf-16le` or `utf-16be`: no BOM unless `opts.bom = true`.
- `opts.bom` has no effect when decoding, or when the target is not UTF-16.
- Pairs of surrogates are combined into one code point above U+FFFF; a lone surrogate is invalid.

## CP1252 and the undefined bytes

CP1252 leaves five bytes undefined: 0x81, 0x8D, 0x8F, 0x90 and 0x9D. charigo follows the WHATWG Encoding Standard (windows-1252) and maps them to the C1 control characters with the same value: U+0081, U+008D, U+008F, U+0090, U+009D. Consequences:

- Every byte from 0x00 to 0xFF decodes; decoding CP1252 never fails.
- The mapping is a bijection, so `cp1252 -> utf-8 -> cp1252` returns the original bytes.
- Encoding U+0081, U+008D, U+008F, U+0090 or U+009D to CP1252 gives back those bytes.
- The other 27 bytes from 0x80 to 0x9F map as in Microsoft's table (for example 0x80 is U+20AC, the euro sign).

This is a choice, not the only possible one: Python's `cp1252` codec rejects those five bytes. charigo does not.

Latin-1 maps each byte to the code point of the same value.

## Detecting the system encoding

```lua
local enc, info = charigo.detect()
```

`enc` is a canonical name usable with the other functions (`"utf-8"`, `"cp1252"`, `"latin1"`, `"utf-16le"`, `"utf-16be"`), or `nil` when the encoding is not detected or not supported. `info` is always a table:

| Field | Meaning |
| --- | --- |
| `source` | Where the answer came from: `"ffi"`, `"reg"`, `"chcp"`, `"env"` or `"none"`. |
| `os` | `"windows"` or `"posix"`. |
| `codepage` | Windows: the ANSI code page number (system encoding). |
| `console_codepage` | Windows: the console output code page number. |
| `console` | Canonical name of the console encoding, when known. On POSIX, equal to `enc`. |
| `raw` | The raw value read: the code page number as text on Windows, the locale string on POSIX. |

Windows:

1. `"ffi"`: under LuaJIT, `GetACP` and `GetConsoleOutputCP` through `ffi`. `enc` is the ANSI code page.
2. `"reg"`: without `ffi`, the ANSI code page is read from the registry with `reg query` through `io.popen`, and the console code page from `chcp`.
3. `"chcp"`: if the registry read fails, only `chcp` is available. `enc` is then `nil` and `codepage` is absent, but `console_codepage` and `console` are set.
4. `"none"`: nothing could be read.

Known code pages: 65001 (utf-8), 1252 (cp1252), 28591 (latin1), 1200 (utf-16le), 1201 (utf-16be). Any other number leaves `enc` (or `console`) at `nil`; read `info.codepage`.

POSIX: the first non-empty of `LC_ALL`, `LC_CTYPE`, `LANG` is taken (`source = "env"`, `raw` is its value). The codeset after the dot (`fr_FR.UTF-8`, `de_DE.ISO-8859-1@euro`) is matched ignoring case, dashes and underscores against `utf8`, `iso88591`, `latin1`, `cp1252`, `windows1252`. A locale like `C` or `POSIX` has no codeset: `enc` is `nil`. If none of the three variables is set, `source = "none"`.

`detect()` never raises. Under Windows without `ffi`, it starts external commands (`reg`, `chcp`) with `io.popen`.

## Supported runtimes

Lua 5.1, 5.2, 5.3, 5.4 and LuaJIT 2.1. The test suite and the bundle run on all of them in CI (Linux). The Windows branch of `detect()` is not run in CI and is checked by hand.

## Interop with zigo

[zigo](https://github.com/wewesss/zigo) validates data at the boundary. Normalize the encoding first, then validate:

```lua
local charigo = require("charigo")
local z = require("zigo")

local name = z.utf8():min(1):max(32)

local function readName(raw, from)
    return name:parse(charigo.convert(raw, from, "utf-8"))
end

print(readName("Ren\233", "cp1252"))
```

`charigo.convert` raises on input that cannot be converted; `z.utf8()` then checks the length rules on well-formed UTF-8.

## Migrating from `map`

The old `lua-charset-converter` module (`map.lua`) is removed. See the migration section of the [changelog](../CHANGELOG.md).
