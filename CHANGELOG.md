# Changelog

All notable changes to charigo are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- README badges, French README, release workflow, community files.
- `bench/compare.lua`, which compares charigo with the native `utf8` library, lua-iconv and the Win32 API through LuaJIT ffi, and `bench/RESULTS.md` with local results.

### Performance

- ASCII shortcut for UTF-8 to Latin-1 and CP1252 on every runtime.
- PUC Lua fast paths: UTF-8 to a single-byte set and UTF-8 to UTF-16 go through `gsub` on a table, with a bounded memo for UTF-16. LuaJIT keeps the plain loops.
- Native validation on Lua 5.4: `valid` calls `utf8.len` first and falls back to the Lua scan for the error position.
- Calibrated benchmark timer in `bench/run.lua`.

## [2.0.0] - 2026-11-09

First stable release and full rewrite. Lua 5.1, 5.2, 5.3, 5.4 and LuaJIT 2.1, zero dependency.

### Added

- Function API: `convert(s, from, to, opts)`, `converter(from, to, opts)` (a reusable function), `decode` and `encode` on code point arrays, `valid(s, enc)` and `detect()`.
- Encodings: UTF-8 (strict RFC 3629: no overlong forms, no surrogates, nothing above U+10FFFF, no truncation), UTF-16LE, UTF-16BE and UTF-16 with BOM handling, Latin-1 and CP1252, with aliases (`utf8`, `latin-1`, `iso-8859-1`, `windows-1252`, ...).
- Error policies through `opts.errors`: `strict` (default, raises with the position), `replace` (U+FFFD, or `?` towards a single-byte set) and `skip`.
- `opts.bom` to write a byte order mark when encoding to UTF-16LE or UTF-16BE.
- CP1252 bytes 0x81, 0x8D, 0x8F, 0x90 and 0x9D map to the C1 controls U+0081, U+008D, U+008F, U+0090 and U+009D (WHATWG), so every byte decodes and the mapping round-trips.
- `detect()` returns the system encoding and an `info` table: `GetACP` and `GetConsoleOutputCP` through `ffi` under LuaJIT on Windows, the registry and `chcp` otherwise, `LC_ALL`, `LC_CTYPE` then `LANG` on POSIX.
- Performance: single-byte sets convert to UTF-8 with `gsub` on a table, ASCII-only input takes a `find` shortcut, converters are cached by `convert`.
- Modules `charigo/{init,utf8,sbcs,utf16,os}.lua`, the single-file bundle `dist/charigo.lua` built by `build.lua`, the `charigo-2.0.0-1` rockspec, English and French guides in `doc/`.
- Tests: a suite run on Lua 5.1 to 5.4 and LuaJIT in CI, a fixed-seed fuzz test (`tests/fuzz_test.lua`), and a benchmark (`bench/run.lua`, with a `--smoke` mode run in CI).

### Removed

- `map.lua` (`lua-charset-converter`) and its method-based API, without a compatibility shim.

### Migration from 1.0.0 (`map`)

| Before | Now |
| --- | --- |
| `map:code1252ToUtf8(s)` | `charigo.convert(s, "cp1252", "utf-8")` |
| `map:utf8ToCode1252(s)` | `charigo.convert(s, "utf-8", "cp1252")` |
| `map:unicodeToUtf8(code)` | `charigo.encode({ code }, "utf-8")` |
| `map:utf8ToUnicode(s, pos)` (one character: `code, size`) | `charigo.decode(s, "utf-8")` (the whole string, as an array of code points) |
| `map:init()` / `map:flush()` | removed: charigo has no global state, tables are built at load time |
| `require("map")` | `require("charigo")` |

Behaviour changes to know about:

- The old CP1252 conversions never worked: `map.lua` looked up a table that did not exist (`map_1252_to_unicode`) and crashed. They work now.
- The old code replaced characters it could not convert with `?` without saying so. Now an unmappable character raises (`charigo: cannot encode U+XXXX in cp1252 at index N`) by default. Pass `{ errors = "replace" }` to get `?`, or `{ errors = "skip" }` to drop it.
- Invalid UTF-8 (overlong forms, surrogates, values above U+10FFFF, truncated sequences) used to be accepted or cut silently. It now raises `charigo: invalid utf-8 at byte N` unless a policy says otherwise.
- `utf8ToUnicode` read one character at a given position; `decode` converts the whole string at once.

## [1.0.0] - 2024-10-25

The legacy `map` module, released as lua-charset-converter.

[2.0.0]: https://github.com/wewesss/charigo/releases/tag/v2.0.0
[1.0.0]: https://github.com/wewesss/charigo/releases/tag/v1.0.0
