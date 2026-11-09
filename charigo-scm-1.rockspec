rockspec_format = "3.0"
package = "charigo"
version = "scm-1"

source = {
    url    = "git+https://github.com/wewesss/charigo.git",
    branch = "main",
}

description = {
    summary  = "Character set conversion for Lua 5.1-5.4 and LuaJIT.",
    detailed = [[
Development build (tracks main). For released versions, install charigo
without specifying scm-1.
]],
    homepage   = "https://github.com/wewesss/charigo",
    license    = "MIT",
    maintainer = "SUP2Ak <cormier.wesley@gmail.com>",
    labels     = { "encoding", "charset", "utf-8", "utf-16", "cp1252", "latin1" },
    issues_url = "https://github.com/wewesss/charigo/issues",
}

dependencies = {
    "lua >= 5.1",
}

build = {
    type = "builtin",
    modules = {
        ["charigo"]       = "charigo/init.lua",
        ["charigo.utf8"]  = "charigo/utf8.lua",
        ["charigo.sbcs"]  = "charigo/sbcs.lua",
        ["charigo.utf16"] = "charigo/utf16.lua",
        ["charigo.os"]    = "charigo/os.lua",
    },
    copy_directories = { "doc" },
}

test = {
    type    = "command",
    command = "lua tests/run.lua",
}
