# Contributing to charigo

charigo is a pure Lua character set conversion library (UTF-8, UTF-16, Latin-1, CP1252). This document explains how to run the project, what a pull request must contain, and how a release is cut.

## Prerequisites

- Lua 5.1, 5.2, 5.3 or 5.4, or LuaJIT 2.1. CI runs all five on Linux; test on at least one locally and let CI cover the rest.
- No runtime dependency is accepted: charigo stays pure Lua.
- If you need a JavaScript runtime for a side script, use `bun`, never `npm` or `npx`.

## Commands

```sh
lua tests/run.lua            # test suite against the source tree
lua build.lua                # build dist/charigo.lua (not committed)
lua tests/run.lua dist       # same suite against the bundle
lua bench/run.lua --smoke    # short benchmark run, as in CI
lua bench/compare.lua        # charigo against the native utf8 library, lua-iconv and the Win32 API
```

Run the first three before opening a pull request. The smoke benchmark only checks that the script still works; a performance claim needs a real run (`lua bench/run.lua`, or `lua bench/compare.lua` for a comparison) with the command and the date. Results from the maintainers are in `bench/RESULTS.md`.

## Pull requests

- Tests for every behaviour change. CI runs the suite and the bundle on Lua 5.1, 5.2, 5.3, 5.4 and LuaJIT; a red cell is about your change.
- `doc/en.md` and `doc/fr.md` are kept in sync: a change to one lands in the other in the same pull request. Error messages stay in English in both.
- A `CHANGELOG.md` entry under `## [Unreleased]`.
- English in code, commit messages and pull request text.
- No comments in the code unless they explain a non-obvious why.
- No AI co-author trailer in any commit message.
- Every number or compatibility claim in a document needs a test, a measurement with its command, or a source URL.

## Releasing

1. Bump the version in the new rockspec (`charigo-X.Y.Z-1.rockspec`, with its `tag`), in `_VERSION` of `charigo/init.lua` and in `CHANGELOG.md` (move `[Unreleased]` under the new version and date).
2. Merge to `main` once CI is green.
3. Tag and push: `git tag vX.Y.Z && git push origin vX.Y.Z`.
4. The `Release` workflow builds the bundle, runs the tests against it and creates a draft release with `charigo-vX.Y.Z.zip`. Review the generated notes and publish the draft.
5. If the `LUAROCKS_API_KEY` secret is set, the same workflow uploads `charigo-X.Y.Z-1.rockspec` to LuaRocks.

The workflow can also be started by hand (Actions, Release, Run workflow) with the name of an existing tag.

## Licensing of contributions

This project is MIT licensed. By submitting a contribution, you agree it is licensed under the same MIT license as the rest of the codebase.

## Reporting a bug

Open a bug with the "Bug report" issue template. Give the charigo version, the Lua runtime, the operating system, a minimal Lua snippet that reproduces the problem, and the expected versus the actual result. For a security issue, follow [SECURITY.md](./SECURITY.md) instead of opening a public issue.
