# Security policy

## Scope

This policy covers the charigo library code: the modules under `charigo/` (`init`, `utf8`, `sbcs`, `utf16`, `os`) and the single-file bundle built from them. It does not cover the tests, the benchmark or the build script.

charigo is a pure Lua library. It makes no network request and writes no file. Conversion functions only read the strings and tables you pass in and return new ones.

`charigo.detect()` is the one function that looks at its environment (`charigo/os.lua`):

- On POSIX it reads the environment variables `LC_ALL`, `LC_CTYPE` and `LANG` with `os.getenv`.
- On Windows under LuaJIT it calls `GetACP` and `GetConsoleOutputCP` through `ffi`.
- On Windows without `ffi` it starts two fixed external commands with `io.popen`: `reg query` on the `HKLM\SYSTEM\CurrentControlSet\Control\Nls\CodePage` key (value `ACP`) and `chcp`. No argument comes from the caller or from the data being converted.

## Supported versions

| Version | Supported |
|---|---|
| Latest 2.x | Yes |
| 1.x (legacy `map` module) | No |

## Reporting a vulnerability

Report a vulnerability using [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability) on this repository (the "Security" tab, "Report a vulnerability"). Do not open a public issue for a security report: a public issue exposes the vulnerability before a fix exists.

If private vulnerability reporting is unavailable to you for any reason, contact the maintainer directly on GitHub (@SUP2Ak) instead. Do not use email for a security report.

Include, where you can: the affected version, or the commit hash if you built from the tree; a minimal Lua reproduction; and the potential impact as you understand it.

## Response targets

These are targets the maintainer intends to meet, not guarantees:

- Acknowledge a new report within 7 days.
- For a confirmed issue, provide a fix or a mitigation plan within 30 days.

A report that turns out not to be a vulnerability, or that needs more information to confirm, may take longer to resolve than these targets.
