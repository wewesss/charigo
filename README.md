# charigo

Character set conversion for Lua 5.1 to 5.4 and LuaJIT: UTF-8 (strict RFC 3629), UTF-16LE/BE, Latin-1 and CP1252, with explicit error policies and system encoding detection. Pure Lua, no dependency.

```lua
local charigo = require("charigo")

print(charigo.convert("caf\233", "cp1252", "utf-8"))
print(pcall(charigo.convert, "\226\130\172", "utf-8", "latin1"))
print(charigo.convert("\226\130\172", "utf-8", "latin1", { errors = "replace" }))
```

Install with `luarocks install charigo`, or copy `charigo/` (or the bundle built by `lua build.lua`).

- [Documentation (English)](./doc/en.md)
- [Documentation (français)](./doc/fr.md)
- [Changelog](./CHANGELOG.md), including the migration from `map` (lua-charset-converter)

License: [MIT](./LICENSE).
