return function(env)
    local test, eq, truthy, raises, charigo = env.test, env.eq, env.truthy, env.raises, env.charigo
    local char = string.char

    local function cpsEq(actual, expected)
        eq(#actual, #expected)
        for i = 1, #expected do eq(actual[i], expected[i]) end
    end

    local function allBytes()
        local t = {}
        for b = 0, 255 do t[#t + 1] = char(b) end
        return table.concat(t)
    end

    local cp1252Low = {
        [0x80] = 0x20AC, [0x81] = 0x0081, [0x82] = 0x201A, [0x83] = 0x0192,
        [0x84] = 0x201E, [0x85] = 0x2026, [0x86] = 0x2020, [0x87] = 0x2021,
        [0x88] = 0x02C6, [0x89] = 0x2030, [0x8A] = 0x0160, [0x8B] = 0x2039,
        [0x8C] = 0x0152, [0x8D] = 0x008D, [0x8E] = 0x017D, [0x8F] = 0x008F,
        [0x90] = 0x0090, [0x91] = 0x2018, [0x92] = 0x2019, [0x93] = 0x201C,
        [0x94] = 0x201D, [0x95] = 0x2022, [0x96] = 0x2013, [0x97] = 0x2014,
        [0x98] = 0x02DC, [0x99] = 0x2122, [0x9A] = 0x0161, [0x9B] = 0x203A,
        [0x9C] = 0x0153, [0x9D] = 0x009D, [0x9E] = 0x017E, [0x9F] = 0x0178,
    }

    test("latin1 round trip of all 256 bytes", function()
        local s = allBytes()
        local cps = charigo.decode(s, "latin1")
        eq(#cps, 256)
        for b = 0, 255 do eq(cps[b + 1], b) end
        eq(charigo.encode(cps, "latin1"), s)
    end)

    for b = 0x80, 0x9F do
        test(("cp1252 byte 0x%02X"):format(b), function()
            cpsEq(charigo.decode(char(b), "cp1252"), { cp1252Low[b] })
            eq(charigo.encode({ cp1252Low[b] }, "cp1252"), char(b))
        end)
    end

    test("cp1252 A0-FF is identity", function()
        for b = 0xA0, 0xFF do
            cpsEq(charigo.decode(char(b), "cp1252"), { b })
        end
    end)

    test("cp1252 round trip of all 256 bytes", function()
        local s = allBytes()
        local cps = charigo.decode(s, "cp1252")
        eq(#cps, 256)
        eq(charigo.encode(cps, "cp1252"), s)
    end)

    test("euro sign in cp1252 and latin1", function()
        eq(charigo.encode({ 0x20AC }, "cp1252"), char(0x80))
        raises(function() charigo.encode({ 0x41, 0x20AC }, "latin1") end,
            "charigo: cannot encode U+20AC in latin1 at index 2")
        eq(charigo.encode({ 0x41, 0x20AC }, "latin1", { errors = "replace" }), "A?")
        eq(charigo.encode({ 0x41, 0x20AC, 0x42 }, "latin1", { errors = "skip" }), "AB")
    end)

    test("cp1252 unmappable code point", function()
        raises(function() charigo.encode({ 0x4E2D }, "cp1252") end,
            "charigo: cannot encode U+4E2D in cp1252 at index 1")
    end)

    test("invalid code point in sbcs encode", function()
        raises(function() charigo.encode({ 0xD800 }, "latin1") end,
            "charigo: invalid code point at index 1")
    end)

    test("aliases and case", function()
        local names = { "latin1", "Latin-1", "ISO-8859-1", "iso-8859-1", "cp1252", "CP1252", "Windows-1252" }
        for i = 1, #names do
            cpsEq(charigo.decode("A", names[i]), { 65 })
        end
        cpsEq(charigo.decode(char(0x80), "WINDOWS-1252"), { 0x20AC })
        cpsEq(charigo.decode(char(0x80), "iso-8859-1"), { 0x80 })
    end)

    test("valid is true for every byte", function()
        truthy(charigo.valid(allBytes(), "latin1"))
        truthy(charigo.valid(allBytes(), "cp1252"))
    end)

    test("unknown encoding still raises", function()
        raises(function() charigo.decode("a", "latin2") end, "charigo: unknown encoding 'latin2'")
    end)

    test("toUtf8 and fromUtf8", function()
        local sbcs = charigo._sbcs
        local cs = sbcs.get("cp1252")
        eq(sbcs.toUtf8(cs, "plain"), "plain")
        eq(sbcs.toUtf8(cs, "a" .. char(0x80) .. char(0xE9)),
            "a" .. char(0xE2, 0x82, 0xAC) .. char(0xC3, 0xA9))
        eq(sbcs.fromUtf8(cs, "plain", "strict"), "plain")
        eq(sbcs.fromUtf8(cs, "a" .. char(0xE2, 0x82, 0xAC) .. char(0xC3, 0xA9), "strict"),
            "a" .. char(0x80) .. char(0xE9))
        local bad = "a" .. char(0xFF) .. "b"
        raises(function() sbcs.fromUtf8(cs, bad, "strict") end, "charigo: invalid utf-8 at byte 2")
        eq(sbcs.fromUtf8(cs, bad, "replace"), "a?b")
        eq(sbcs.fromUtf8(cs, bad, "skip"), "ab")
    end)
end
