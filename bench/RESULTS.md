# Benchmark results

Date: 2026-11-12. Machine: Windows 11, local run, not CI. Numbers are MB/s of input, best of 3 samples of at least 0.2 s each, input about 1 MiB. They move by 10 to 15 percent between runs on this machine: read them as orders of magnitude, not as exact figures. Other machines and Lua builds will differ.

Runtimes: `lua` is Lua 5.4, `lua5.3` is Lua 5.3, `luajit` is LuaJIT 2.1 (all from the MSYS2 mingw64 toolchain). Lua 5.1 and 5.2 were not run locally; CI covers them.

## What changed in 2.1

- Every runtime: UTF-8 to Latin-1 or CP1252 returns ASCII input as is.
- PUC Lua only (not LuaJIT, where `gsub` on non-ASCII input is slower than the plain loop): UTF-8 to a single-byte set and UTF-8 to UTF-16 go through `gsub` on a table.
- Lua 5.4 only: `charigo.valid(s, "utf-8")` calls the native `utf8.len` first.
- PUC Lua only: UTF-16 (LE, BE or with BOM) to UTF-8 goes through `gsub` on a two-byte table, with a bounded memo. Input with a surrogate (a pair or a lone one) or an odd length falls back to the generic path, which keeps its errors and policies.

## Before and after

Before is `main` at commit 0c3c885, after is the `perf-2-1` branch, both measured with the new calibrated `bench/run.lua`. Each runtime was run 3 times, alternating before and after, and the best value per row is kept. The after run always follows the before run, so a ratio between 0.85 and 1.15 on a row the branch did not touch is noise (a separate 3-run check of `utf-16le -> utf-8` on LuaJIT gave 103 against 104 MB/s). One LuaJIT row is a real cost, measured again in 3 separate runs: `utf-8 -> cp1252` on French text goes from about 62 to about 54 MB/s, because the ASCII shortcut adds a `find` that LuaJIT does not compile, and non-ASCII input gets nothing in return. ASCII input on LuaJIT goes from 44 to 251 MB/s.

Commands, from the repository root (the before copy is `git archive main` with the new `bench/run.lua`):

```sh
lua bench/run.lua
luajit bench/run.lua
```

### Lua 5.4

| scenario | input | before MB/s | after MB/s | ratio |
| --- | --- | ---: | ---: | ---: |
| convert utf-8 -> cp1252 | ascii | 14.6 | 136.6 | 9.36x |
| convert utf-8 -> cp1252 | french | 16.7 | 73.9 | 4.43x |
| convert cp1252 -> utf-8 | ascii | 136.6 | 137.9 | 1.01x |
| convert cp1252 -> utf-8 | french | 84.1 | 82.9 | 0.99x |
| convert utf-8 -> utf-16le | ascii | 6.3 | 33.2 | 5.27x |
| convert utf-8 -> utf-16le | french | 6.6 | 25.5 | 3.86x |
| convert utf-8 -> utf-16le | emoji | 8.2 | 34.0 | 4.15x |
| convert utf-16le -> utf-8 | ascii | 16.3 | 15.9 | 0.98x |
| convert utf-16le -> utf-8 | french | 15.8 | 14.2 | 0.90x |
| convert utf-16le -> utf-8 | emoji | 12.4 | 13.3 | 1.07x |
| valid utf-8 | ascii | 127.5 | 1447.8 | 11.36x |
| valid utf-8 | french | 38.1 | 875.7 | 22.98x |
| valid utf-8 | emoji | 24.9 | 990.1 | 39.76x |
| small convert utf-8 -> utf-16le | ascii | 5.9 | 26.0 | 4.41x |
| small converter utf-8 -> utf-16le | ascii | 5.7 | 30.2 | 5.30x |
| small convert utf-8 -> utf-16le | french | 5.7 | 21.3 | 3.74x |
| small converter utf-8 -> utf-16le | french | 6.2 | 23.8 | 3.84x |
| small convert utf-8 -> utf-16le | emoji | 5.6 | 25.3 | 4.52x |
| small converter utf-8 -> utf-16le | emoji | 7.1 | 29.1 | 4.10x |

### LuaJIT 2.1

| scenario | input | before MB/s | after MB/s | ratio |
| --- | --- | ---: | ---: | ---: |
| convert utf-8 -> cp1252 | ascii | 44.3 | 251.2 | 5.67x |
| convert utf-8 -> cp1252 | french | 95.2 | 76.6 | 0.80x |
| convert cp1252 -> utf-8 | ascii | 246.3 | 253.7 | 1.03x |
| convert cp1252 -> utf-8 | french | 81.5 | 83.3 | 1.02x |
| convert utf-8 -> utf-16le | ascii | 26.1 | 24.3 | 0.93x |
| convert utf-8 -> utf-16le | french | 47.4 | 44.3 | 0.93x |
| convert utf-8 -> utf-16le | emoji | 51.2 | 49.5 | 0.97x |
| convert utf-16le -> utf-8 | ascii | 117.1 | 98.0 | 0.84x |
| convert utf-16le -> utf-8 | french | 118.4 | 102.0 | 0.86x |
| convert utf-16le -> utf-8 | emoji | 95.7 | 82.9 | 0.87x |
| valid utf-8 | ascii | 250.0 | 255.0 | 1.02x |
| valid utf-8 | french | 105.8 | 103.5 | 0.98x |
| valid utf-8 | emoji | 120.2 | 117.7 | 0.98x |
| small convert utf-8 -> utf-16le | ascii | 5.8 | 5.8 | 1.00x |
| small converter utf-8 -> utf-16le | ascii | 5.8 | 6.0 | 1.03x |
| small convert utf-8 -> utf-16le | french | 39.7 | 38.8 | 0.98x |
| small converter utf-8 -> utf-16le | french | 39.9 | 41.5 | 1.04x |
| small convert utf-8 -> utf-16le | emoji | 39.2 | 39.9 | 1.02x |
| small converter utf-8 -> utf-16le | emoji | 39.7 | 40.7 | 1.03x |

### UTF-16 to UTF-8 fast path

Before is `main` at commit 126e2b2, after is the `perf-utf16-decode` branch, same `bench/run.lua`, 3 runs each, best value per row. The 3 before runs were made first, then the 3 after runs, so a ratio between 0.85 and 1.15 is noise. Input is UTF-16LE, `convert utf-16le -> utf-8`.

| runtime | input | before MB/s | after MB/s | ratio |
| --- | --- | ---: | ---: | ---: |
| Lua 5.4 | ascii | 16.5 | 80.0 | 4.85x |
| Lua 5.4 | french | 16.2 | 73.9 | 4.56x |
| Lua 5.4 | emoji | 14.4 | 11.5 | 0.80x |
| LuaJIT 2.1 | ascii | 102.8 | 109.5 | 1.07x |
| LuaJIT 2.1 | french | 113.4 | 114.5 | 1.01x |
| LuaJIT 2.1 | emoji | 93.9 | 94.3 | 1.00x |

The `emoji` input holds surrogate pairs, so the fast path runs `gsub` to the end, sees the miss flag and falls back to the generic path: that costs about 20 percent on PUC Lua for text with characters outside the BMP. LuaJIT does not use the fast path. One LuaJIT after run came out at 64 to 74 MB/s on these rows, an outlier on this machine that the other two runs do not show.

## Against other tools

`bench/compare.lua` runs the same inputs and timer against the native `utf8` library (Lua 5.3+), lua-iconv, and the Win32 conversion functions through LuaJIT ffi. A tool that cannot load prints `absent (<reason>)`. lua-iconv is only built for Lua 5.4 here, so the Lua 5.3 and LuaJIT runs report it as absent. The Win32 rows include the buffer allocation and the copy back to a Lua string. `utf8.len`, `utf8.codes` and `utf8.char` are the native baseline; charigo is compared on the same work. On Lua 5.3 `charigo.valid` stays on the pure Lua scan, because the 5.3 `utf8.len` accepts surrogates.

Commands:

```sh
lua bench/compare.lua
lua5.3 bench/compare.lua
luajit bench/compare.lua
```

### `lua bench/compare.lua`

Runtime: Lua 5.4. Date: 2026-11-12. Input ~1048576 bytes. Ratio = charigo / competitor.

| scenario | input | charigo MB/s | competitor | competitor MB/s | ratio |
| --- | --- | ---: | --- | ---: | ---: |
| validate utf-8 | ascii | 1490.0 | utf8 (native) | 1383.1 | 1.08x |
| utf-8 -> code points | ascii | 24.5 | utf8 (native) | 31.5 | 0.78x |
| code points -> utf-8 | ascii | 15.9 | utf8 (native) | 28.0 | 0.57x |
| validate utf-8 | french | 825.9 | utf8 (native) | 830.1 | 1.00x |
| utf-8 -> code points | french | 22.4 | utf8 (native) | 35.1 | 0.64x |
| code points -> utf-8 | french | 13.8 | utf8 (native) | 30.0 | 0.46x |
| validate utf-8 | emoji | 840.0 | utf8 (native) | 945.3 | 0.89x |
| utf-8 -> code points | emoji | 19.2 | utf8 (native) | 44.6 | 0.43x |
| code points -> utf-8 | emoji | 15.6 | utf8 (native) | 43.1 | 0.36x |
| (all) | - | - | Win32 API (ffi) | absent (needs LuaJIT with ffi) | - |

### lua-iconv

lua-iconv 7, built locally against Lua 5.4 and the msys2 libiconv on Windows 11, 2026-11-12. Command, from the repository root, with the built module on `LUA_CPATH`:

```sh
LUA_CPATH="<build dir>/?.dll;;" lua bench/compare.lua
```

iconv is C and is expected to be faster. The point of this table is the size of the gap, not a contest. Ratio = charigo / lua-iconv, input about 1 MiB, best of 3 samples, charigo with the fast paths of this branch.

| scenario | input | charigo MB/s | lua-iconv MB/s | ratio |
| --- | --- | ---: | ---: | ---: |
| utf-8 -> cp1252 | ascii | 133.7 | 300.5 | 0.44x |
| utf-8 -> cp1252 | french | 71.4 | 335.0 | 0.21x |
| cp1252 -> utf-8 | ascii | 137.9 | 297.0 | 0.46x |
| cp1252 -> utf-8 | french | 82.5 | 310.2 | 0.27x |
| utf-8 -> latin1 | ascii | 135.3 | 308.5 | 0.44x |
| utf-8 -> latin1 | latin1 | 73.2 | 313.5 | 0.23x |
| latin1 -> utf-8 | ascii | 136.6 | 341.6 | 0.40x |
| latin1 -> utf-8 | latin1 | 83.5 | 337.1 | 0.25x |
| utf-8 -> utf-16le | ascii | 32.9 | 262.4 | 0.13x |
| utf-8 -> utf-16le | french | 25.5 | 277.2 | 0.09x |
| utf-8 -> utf-16le | emoji | 33.7 | 348.3 | 0.10x |
| utf-16le -> utf-8 | ascii | 76.9 | 607.9 | 0.13x |
| utf-16le -> utf-8 | french | 72.2 | 586.4 | 0.12x |
| utf-16le -> utf-8 | emoji | 10.8 | 546.9 | 0.02x |

In short: lua-iconv is about 2 to 5 times faster on single-byte sets and about 8 to 11 times faster on UTF-16 (about 50 times on UTF-16 holding surrogate pairs, which take the generic path in charigo).

### `lua5.3 bench/compare.lua`

Runtime: Lua 5.3. Date: 2026-11-12. Input ~1048576 bytes. Ratio = charigo / competitor.

| scenario | input | charigo MB/s | competitor | competitor MB/s | ratio |
| --- | --- | ---: | --- | ---: | ---: |
| validate utf-8 | ascii | 151.2 | utf8 (native) | 1482.6 | 0.10x |
| utf-8 -> code points | ascii | 24.3 | utf8 (native) | 31.5 | 0.77x |
| code points -> utf-8 | ascii | 12.8 | utf8 (native) | 24.5 | 0.52x |
| validate utf-8 | french | 39.2 | utf8 (native) | 820.1 | 0.05x |
| utf-8 -> code points | french | 19.7 | utf8 (native) | 36.4 | 0.54x |
| code points -> utf-8 | french | 10.6 | utf8 (native) | 24.2 | 0.44x |
| validate utf-8 | emoji | 20.8 | utf8 (native) | 756.2 | 0.03x |
| utf-8 -> code points | emoji | 14.8 | utf8 (native) | 44.3 | 0.33x |
| code points -> utf-8 | emoji | 11.8 | utf8 (native) | 29.6 | 0.40x |
| (all) | - | - | lua-iconv | absent (module 'iconv' not found:) | - |
| (all) | - | - | Win32 API (ffi) | absent (needs LuaJIT with ffi) | - |

### `luajit bench/compare.lua`

Runtime: LuaJIT 2.1.1727870382. Date: 2026-11-12. Input ~1048576 bytes. Ratio = charigo / competitor.

| scenario | input | charigo MB/s | competitor | competitor MB/s | ratio |
| --- | --- | ---: | --- | ---: | ---: |
| (all) | - | - | utf8 (native) | absent (needs Lua 5.3 or later) | - |
| (all) | - | - | lua-iconv | absent (module 'iconv' not found:) | - |
| utf-8 -> utf-16le | ascii | 23.0 | Win32 API (ffi) | 1505.0 | 0.02x |
| utf-8 -> utf-16le | french | 42.7 | Win32 API (ffi) | 766.2 | 0.06x |
| utf-8 -> utf-16le | emoji | 46.5 | Win32 API (ffi) | 651.8 | 0.07x |
| utf-16le -> utf-8 | ascii | 118.2 | Win32 API (ffi) | 1756.1 | 0.07x |
| utf-16le -> utf-8 | french | 116.1 | Win32 API (ffi) | 1308.8 | 0.09x |
| utf-16le -> utf-8 | emoji | 92.1 | Win32 API (ffi) | 994.3 | 0.09x |
| cp1252 -> utf-8 | ascii | 240.0 | Win32 API (ffi) | 699.0 | 0.34x |
| cp1252 -> utf-8 | french | 69.8 | Win32 API (ffi) | 611.0 | 0.11x |
