return function(env)
    local test, eq, raises, charigo = env.test, env.eq, env.raises, env.charigo
    local char = string.char

    local function cpsEq(actual, expected)
        eq(#actual, #expected)
        for i = 1, #expected do eq(actual[i], expected[i]) end
    end

    local LE, BE = "utf-16le", "utf-16be"
    local smile = { LE = char(0x3D, 0xD8, 0x00, 0xDE), BE = char(0xD8, 0x3D, 0xDE, 0x00) }
    local maxcp = { LE = char(0xFF, 0xDB, 0xFF, 0xDF), BE = char(0xDB, 0xFF, 0xDF, 0xFF) }

    test("bmp decode both endiannesses", function()
        cpsEq(charigo.decode(char(0x41, 0x00, 0xAC, 0x20), LE), { 0x41, 0x20AC })
        cpsEq(charigo.decode(char(0x00, 0x41, 0x20, 0xAC), BE), { 0x41, 0x20AC })
    end)

    test("bmp encode both endiannesses", function()
        eq(charigo.encode({ 0x41, 0x20AC }, LE), char(0x41, 0x00, 0xAC, 0x20))
        eq(charigo.encode({ 0x41, 0x20AC }, BE), char(0x00, 0x41, 0x20, 0xAC))
    end)

    test("code points just around the surrogate range", function()
        local cps = { 0xD7FF, 0xE000, 0xFFFF }
        eq(charigo.encode(cps, LE), char(0xFF, 0xD7, 0x00, 0xE0, 0xFF, 0xFF))
        cpsEq(charigo.decode(charigo.encode(cps, BE), BE), cps)
    end)

    test("supplementary U+1F600", function()
        eq(charigo.encode({ 0x1F600 }, LE), smile.LE)
        eq(charigo.encode({ 0x1F600 }, BE), smile.BE)
        cpsEq(charigo.decode(smile.LE, LE), { 0x1F600 })
        cpsEq(charigo.decode(smile.BE, BE), { 0x1F600 })
    end)

    test("supplementary U+10FFFF and U+10000", function()
        eq(charigo.encode({ 0x10FFFF }, LE), maxcp.LE)
        eq(charigo.encode({ 0x10FFFF }, BE), maxcp.BE)
        cpsEq(charigo.decode(maxcp.LE, LE), { 0x10FFFF })
        cpsEq(charigo.decode(maxcp.BE, BE), { 0x10FFFF })
        eq(charigo.encode({ 0x10000 }, BE), char(0xD8, 0x00, 0xDC, 0x00))
        cpsEq(charigo.decode(char(0xD8, 0x00, 0xDC, 0x00), BE), { 0x10000 })
    end)

    test("empty input", function()
        cpsEq(charigo.decode("", LE), {})
        eq(charigo.encode({}, BE), "")
        eq(charigo.encode({}, "utf-16"), char(0xFF, 0xFE))
    end)

    test("names are case-insensitive and have aliases", function()
        local s = char(0x41, 0x00)
        local names = { "UTF-16LE", "utf16le", "Utf-16Le", "UTF16LE" }
        for i = 1, #names do cpsEq(charigo.decode(s, names[i]), { 0x41 }) end
        cpsEq(charigo.decode(char(0x00, 0x41), "UTF16BE"), { 0x41 })
        cpsEq(charigo.decode(s, "UTF16"), { 0x41 })
        cpsEq(charigo.decode(s, "UTF-16"), { 0x41 })
    end)

    test("le strips its own BOM once and keeps the other", function()
        cpsEq(charigo.decode(char(0xFF, 0xFE, 0x41, 0x00), LE), { 0x41 })
        cpsEq(charigo.decode(char(0xFF, 0xFE, 0xFF, 0xFE, 0x41, 0x00), LE), { 0xFEFF, 0x41 })
        cpsEq(charigo.decode(char(0xFE, 0xFF, 0x41, 0x00), LE), { 0xFFFE, 0x41 })
    end)

    test("be strips its own BOM once and keeps the other", function()
        cpsEq(charigo.decode(char(0xFE, 0xFF, 0x00, 0x41), BE), { 0x41 })
        cpsEq(charigo.decode(char(0xFE, 0xFF, 0xFE, 0xFF, 0x00, 0x41), BE), { 0xFEFF, 0x41 })
        cpsEq(charigo.decode(char(0xFF, 0xFE, 0x00, 0x41), BE), { 0xFFFE, 0x41 })
    end)

    test("utf-16 reads the BOM, defaults to LE", function()
        cpsEq(charigo.decode(char(0xFF, 0xFE, 0x41, 0x00), "utf-16"), { 0x41 })
        cpsEq(charigo.decode(char(0xFE, 0xFF, 0x00, 0x41), "utf-16"), { 0x41 })
        cpsEq(charigo.decode(char(0x41, 0x00), "utf-16"), { 0x41 })
        cpsEq(charigo.decode(char(0x00, 0x41), "utf-16"), { 0x4100 })
        cpsEq(charigo.decode(char(0xFF, 0xFE), "utf-16"), {})
    end)

    test("encode without BOM by default, with opts.bom", function()
        eq(charigo.encode({ 0x41 }, LE), char(0x41, 0x00))
        eq(charigo.encode({ 0x41 }, LE, { bom = true }), char(0xFF, 0xFE, 0x41, 0x00))
        eq(charigo.encode({ 0x41 }, BE, { bom = true }), char(0xFE, 0xFF, 0x00, 0x41))
        eq(charigo.encode({ 0x41 }, BE, { bom = false }), char(0x00, 0x41))
    end)

    test("utf-16 encodes LE with a BOM", function()
        eq(charigo.encode({ 0x41 }, "utf-16"), char(0xFF, 0xFE, 0x41, 0x00))
        eq(charigo.encode({ 0x41 }, "utf16", { bom = true }), char(0xFF, 0xFE, 0x41, 0x00))
    end)

    test("BOM round trips", function()
        local cps = { 0x41, 0x1F600, 0x20AC }
        cpsEq(charigo.decode(charigo.encode(cps, LE, { bom = true }), LE), cps)
        cpsEq(charigo.decode(charigo.encode(cps, BE, { bom = true }), BE), cps)
        cpsEq(charigo.decode(charigo.encode(cps, "utf-16"), "utf-16"), cps)
    end)

    local loneHighLE = char(0x3D, 0xD8)
    local loneLowLE = char(0x00, 0xDE)
    local a = char(0x41, 0x00)

    test("lone high surrogate at start, middle, end: strict position", function()
        raises(function() charigo.decode(loneHighLE .. a, LE) end, "charigo: invalid utf-16 at byte 1")
        raises(function() charigo.decode(a .. loneHighLE .. a, LE) end, "charigo: invalid utf-16 at byte 3")
        raises(function() charigo.decode(a .. loneHighLE, LE) end, "charigo: invalid utf-16 at byte 3")
    end)

    test("lone low surrogate at start, middle, end: strict position", function()
        raises(function() charigo.decode(loneLowLE .. a, LE) end, "charigo: invalid utf-16 at byte 1")
        raises(function() charigo.decode(a .. loneLowLE .. a, LE) end, "charigo: invalid utf-16 at byte 3")
        raises(function() charigo.decode(a .. loneLowLE, LE) end, "charigo: invalid utf-16 at byte 3")
    end)

    test("reversed pair and high followed by BMP are invalid", function()
        raises(function() charigo.decode(char(0x00, 0xDE, 0x3D, 0xD8), LE) end, "at byte 1")
        raises(function() charigo.decode(loneHighLE .. loneHighLE, LE) end, "at byte 1")
        raises(function() charigo.decode(char(0xD8, 0x3D, 0x00, 0x41), BE) end, "at byte 1")
    end)

    test("odd length: strict position of the trailing byte", function()
        raises(function() charigo.decode(char(0x41), LE) end, "charigo: invalid utf-16 at byte 1")
        raises(function() charigo.decode(a .. char(0x42), BE) end, "charigo: invalid utf-16 at byte 3")
        raises(function() charigo.decode(smile.LE .. char(0x42), LE) end, "charigo: invalid utf-16 at byte 5")
    end)

    test("errors carry no position prefix (level 0)", function()
        local ok, err = pcall(charigo.decode, loneLowLE, LE)
        eq(ok, false)
        eq(err, "charigo: invalid utf-16 at byte 1")
    end)

    test("replace: one U+FFFD per bad unit", function()
        cpsEq(charigo.decode(a .. loneHighLE .. a, LE, { errors = "replace" }), { 0x41, 0xFFFD, 0x41 })
        cpsEq(charigo.decode(loneLowLE .. a, LE, { errors = "replace" }), { 0xFFFD, 0x41 })
        cpsEq(charigo.decode(loneHighLE .. loneHighLE, LE, { errors = "replace" }), { 0xFFFD, 0xFFFD })
    end)

    test("replace: odd trailing byte gives one U+FFFD", function()
        cpsEq(charigo.decode(a .. char(0x42), LE, { errors = "replace" }), { 0x41, 0xFFFD })
        cpsEq(charigo.decode(loneHighLE .. char(0x42), LE, { errors = "replace" }), { 0xFFFD, 0xFFFD })
    end)

    test("skip drops bad units and the odd byte", function()
        cpsEq(charigo.decode(a .. loneHighLE .. a, LE, { errors = "skip" }), { 0x41, 0x41 })
        cpsEq(charigo.decode(loneLowLE .. a .. char(0x42), LE, { errors = "skip" }), { 0x41 })
    end)

    test("valid returns true, or false and the position", function()
        eq(charigo.valid(a .. smile.LE, LE), true)
        eq(charigo.valid("", BE), true)
        local ok, pos = charigo.valid(a .. loneLowLE, LE)
        eq(ok, false)
        eq(pos, 3)
        ok, pos = charigo.valid(a .. char(0x42), "utf-16")
        eq(ok, false)
        eq(pos, 3)
        ok, pos = charigo.valid(loneHighLE, LE)
        eq(ok, false)
        eq(pos, 1)
    end)

    test("valid accounts for the BOM in positions", function()
        local ok, pos = charigo.valid(char(0xFF, 0xFE) .. loneLowLE, LE)
        eq(ok, false)
        eq(pos, 3)
    end)

    test("encode invalid code points: strict, replace, skip", function()
        local bad = { 0x41, 0xD800, 0x110000, -1, 1.5, "x" }
        raises(function() charigo.encode({ 0x41, 0xD800 }, LE) end, "charigo: invalid code point at index 2")
        raises(function() charigo.encode({ 0x41, 0x110000 }, BE) end, "charigo: invalid code point at index 2")
        raises(function() charigo.encode({ 0x41, "x" }, LE) end, "at index 2")
        eq(charigo.encode(bad, LE, { errors = "replace" }),
            char(0x41, 0x00) .. string.rep(char(0xFD, 0xFF), 5))
        eq(charigo.encode(bad, BE, { errors = "skip" }), char(0x00, 0x41))
    end)

    test("unknown errors policy keeps its wording", function()
        raises(function() charigo.decode(a, LE, { errors = "nope" }) end, "unknown errors policy 'nope'")
        raises(function() charigo.encode({ 1 }, LE, { errors = "nope" }) end, "unknown errors policy 'nope'")
    end)

    test("large input spanning several chunks", function()
        local cps = {}
        for i = 1, 20000 do cps[i] = (i % 2 == 0) and 0x1F600 or (0x20 + i % 0x5000) end
        local encs = { LE, BE, "utf-16" }
        for i = 1, #encs do
            cpsEq(charigo.decode(charigo.encode(cps, encs[i]), encs[i]), cps)
        end
    end)
end
