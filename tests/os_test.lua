return function(env)
    local test, eq, falsy, charigo = env.test, env.eq, env.falsy, env.charigo
    local sysos = charigo._os

    local function posix(vars)
        return sysos.detect({
            is_windows = false,
            getenv = function(name) return vars[name] end,
        })
    end

    local function fakeFfi(acp, console)
        return {
            cdef = function() end,
            C = {
                GetACP = function() return acp end,
                GetConsoleOutputCP = function() return console end,
            },
        }
    end

    local function fakePopen(output)
        return function()
            return { read = function() return output end, close = function() end }
        end
    end

    test("posix LC_ALL wins over LC_CTYPE and LANG", function()
        local enc, info = posix({ LC_ALL = "de_DE.ISO-8859-1", LC_CTYPE = "en_US.UTF-8", LANG = "en_US.UTF-8" })
        eq(enc, "latin1")
        eq(info.raw, "de_DE.ISO-8859-1")
    end)

    test("posix LC_CTYPE wins over LANG", function()
        eq((posix({ LC_CTYPE = "xx.CP1252", LANG = "en_US.UTF-8" })), "cp1252")
    end)

    test("posix LANG is the last resort", function()
        eq((posix({ LANG = "en_US.UTF-8" })), "utf-8")
    end)

    test("posix empty string is skipped", function()
        local enc, info = posix({ LC_ALL = "", LC_CTYPE = "", LANG = "fr_FR.utf8" })
        eq(enc, "utf-8")
        eq(info.raw, "fr_FR.utf8")
    end)

    test("posix codesets", function()
        eq((posix({ LANG = "en_US.UTF-8" })), "utf-8")
        eq((posix({ LANG = "fr_FR.utf8" })), "utf-8")
        eq((posix({ LANG = "de_DE.ISO-8859-1" })), "latin1")
        eq((posix({ LANG = "xx.CP1252" })), "cp1252")
        eq((posix({ LANG = "xx.windows-1252" })), "cp1252")
        eq((posix({ LANG = "sr_RS.UTF-8@latin" })), "utf-8")
    end)

    test("posix info fields", function()
        local enc, info = posix({ LANG = "en_US.UTF-8" })
        eq(info.os, "posix")
        eq(info.source, "env")
        eq(info.console, enc)
        eq(info.codepage, nil)
        eq(info.console_codepage, nil)
    end)

    test("posix C and POSIX have no encoding", function()
        local enc, info = posix({ LANG = "C" })
        eq(enc, nil)
        eq(info.source, "env")
        eq(info.console, nil)
        eq((posix({ LC_ALL = "POSIX" })), nil)
    end)

    test("posix unknown codeset", function()
        eq((posix({ LANG = "ja_JP.eucJP" })), nil)
    end)

    test("posix unset gives source none", function()
        local enc, info = posix({})
        eq(enc, nil)
        eq(info.source, "none")
        eq(info.os, "posix")
        eq(info.raw, nil)
    end)

    test("windows ffi with an OEM console", function()
        local enc, info = sysos.detect({ is_windows = true, ffi = fakeFfi(1252, 850) })
        eq(enc, "cp1252")
        eq(info.os, "windows")
        eq(info.source, "ffi")
        eq(info.codepage, 1252)
        eq(info.console, nil)
        eq(info.console_codepage, 850)
    end)

    test("windows ffi utf-8", function()
        local enc, info = sysos.detect({ is_windows = true, ffi = fakeFfi(65001, 65001) })
        eq(enc, "utf-8")
        eq(info.console, "utf-8")
        eq(info.console_codepage, 65001)
    end)

    test("windows ffi failure falls back to chcp", function()
        local broken = { cdef = function() end, C = {} }
        local enc, info = sysos.detect({
            is_windows = true, ffi = broken, popen = fakePopen("Active code page: 65001"),
        })
        eq(enc, "utf-8")
        eq(info.source, "chcp")
    end)

    test("windows chcp localized output", function()
        local enc, info = sysos.detect({
            is_windows = true, ffi = false, popen = fakePopen("Page de codes active : 850\n"),
        })
        eq(enc, nil)
        eq(info.source, "chcp")
        eq(info.codepage, 850)
        eq(info.console_codepage, 850)
        eq(info.raw, "850")
    end)

    test("windows chcp utf-8", function()
        local enc, info = sysos.detect({
            is_windows = true, ffi = false, popen = fakePopen("Active code page: 65001"),
        })
        eq(enc, "utf-8")
        eq(info.console, "utf-8")
        eq(info.codepage, 65001)
    end)

    test("windows popen failing gives source none", function()
        local _, info = sysos.detect({
            is_windows = true, ffi = false, popen = function() error("boom") end,
        })
        eq(info.source, "none")
        local enc, info2 = sysos.detect({ is_windows = true, ffi = false, popen = function() return nil end })
        eq(enc, nil)
        eq(info2.source, "none")
        local _, info3 = sysos.detect({ is_windows = true, ffi = false, popen = false })
        eq(info3.source, "none")
    end)

    test("windows chcp without a number gives source none", function()
        local _, info = sysos.detect({ is_windows = true, ffi = false, popen = fakePopen("oops") })
        eq(info.source, "none")
    end)

    test("real detect returns without error", function()
        local enc, info = charigo.detect()
        eq(type(info), "table")
        eq(type(info.os), "string")
        falsy(enc ~= nil and type(enc) ~= "string")
    end)
end
