# charigo — release bundle

Character set conversion for Lua 5.1, 5.2, 5.3, 5.4 and LuaJIT: UTF-8 (strict RFC 3629), UTF-16LE/BE, Latin-1 and CP1252, with explicit error policies and system encoding detection. Pure Lua, no dependency.

## What's in this archive

```
charigo.lua           ← single-file bundled distribution
LICENSE
README.md             ← this file
```

## Install

Drop `charigo.lua` anywhere on your `package.path`, then:

```lua
local charigo = require("charigo")

print(charigo.convert("caf\233", "cp1252", "utf-8"))
print(pcall(charigo.convert, "\226\130\172", "utf-8", "latin1"))
print(charigo.convert("\226\130\172", "utf-8", "latin1", { errors = "replace" }))
```

If `package.path` is awkward in your context, you can also load directly:

```lua
local charigo = dofile("path/to/charigo.lua")
```

## Documentation & sources

- Repository: https://github.com/wewesss/charigo
- Guides (English and French), error messages, encoding detection: in `doc/` on the repo ([English](https://github.com/wewesss/charigo/blob/main/doc/en.md), [Français](https://github.com/wewesss/charigo/blob/main/doc/fr.md)).

## License

[MIT](./LICENSE) — Copyright (c) 2026 Wesley Cormier (SUP2Ak).
