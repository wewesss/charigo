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

    local function fakePopen(reg, chcp)
        return function(command)
            local output = command:find("^reg ") and reg or chcp
            if output == nil then error("boom") end
            if output == false then return nil end
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

    test("windows ffi failure falls back to the registry", function()
        local broken = { cdef = function() end, C = {} }
        local enc, info = sysos.detect({
            is_windows = true, ffi = broken,
            popen = fakePopen("    ACP    REG_SZ    1252", "Active code page: 65001"),
        })
        eq(enc, "cp1252")
        eq(info.source, "reg")
    end)

    test("windows without ffi reads ACP from the registry and console from chcp", function()
        local enc, info = sysos.detect({
            is_windows = true, ffi = false,
            popen = fakePopen("    ACP    REG_SZ    1252", "Page de codes active : 850\n"),
        })
        eq(enc, "cp1252")
        eq(info.source, "reg")
        eq(info.codepage, 1252)
        eq(info.console, nil)
        eq(info.console_codepage, 850)
        eq(info.raw, "1252")
    end)

    test("windows without ffi utf-8", function()
        local enc, info = sysos.detect({
            is_windows = true, ffi = false,
            popen = fakePopen("    ACP    REG_SZ    65001", "Active code page: 65001"),
        })
        eq(enc, "utf-8")
        eq(info.console, "utf-8")
    end)

    test("windows registry failing leaves only the console code page", function()
        for _, reg in ipairs({ "garbage", false }) do
            local enc, info = sysos.detect({
                is_windows = true, ffi = false,
                popen = fakePopen(reg, "Active code page: 850"),
            })
            eq(enc, nil)
            eq(info.source, "chcp")
            eq(info.codepage, nil)
            eq(info.console_codepage, 850)
            eq(info.raw, "850")
        end
    end)

    test("windows registry alone gives source reg", function()
        local enc, info = sysos.detect({
            is_windows = true, ffi = false,
            popen = fakePopen("    ACP    REG_SZ    1252", "oops"),
        })
        eq(enc, "cp1252")
        eq(info.source, "reg")
        eq(info.console_codepage, nil)
    end)

    test("windows without any answer gives source none", function()
        local enc, info = sysos.detect({
            is_windows = true, ffi = false, popen = fakePopen(nil, nil),
        })
        eq(enc, nil)
        eq(info.source, "none")
        eq(info.codepage, nil)
        eq(info.raw, nil)
        local _, info2 = sysos.detect({ is_windows = true, ffi = false, popen = fakePopen("x", "oops") })
        eq(info2.source, "none")
        local _, info3 = sysos.detect({ is_windows = true, ffi = false, popen = false })
        eq(info3.source, "none")
    end)

    test("real detect returns without error", function()
        local enc, info = charigo.detect()
        eq(type(info), "table")
        eq(type(info.os), "string")
        falsy(enc ~= nil and type(enc) ~= "string")
    end)
end
