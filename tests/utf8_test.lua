return function(env)
    local test, eq, truthy, falsy, raises, charigo =
        env.test, env.eq, env.truthy, env.falsy, env.raises, env.charigo
    local char = string.char

    local function cpsEq(actual, expected)
        eq(#actual, #expected)
        for i = 1, #expected do eq(actual[i], expected[i]) end
    end

    local function bytes(...) return char(...) end

    test("decode ASCII", function()
        cpsEq(charigo.decode("Abc", "utf-8"), { 65, 98, 99 })
    end)

    test("decode empty string", function()
        cpsEq(charigo.decode("", "utf-8"), {})
        eq(charigo.encode({}, "utf-8"), "")
    end)

    test("decode 2, 3 and 4 byte sequences", function()
        cpsEq(charigo.decode(bytes(0xC3, 0xA9), "utf-8"), { 0xE9 })
        cpsEq(charigo.decode(bytes(0xE2, 0x82, 0xAC), "utf-8"), { 0x20AC })
        cpsEq(charigo.decode(bytes(0xF0, 0x9F, 0x98, 0x80), "utf-8"), { 0x1F600 })
    end)

    local boundaries = {
        { 0x7F, bytes(0x7F) },
        { 0x80, bytes(0xC2, 0x80) },
        { 0x7FF, bytes(0xDF, 0xBF) },
        { 0x800, bytes(0xE0, 0xA0, 0x80) },
        { 0xFFFF, bytes(0xEF, 0xBF, 0xBF) },
        { 0x10000, bytes(0xF0, 0x90, 0x80, 0x80) },
        { 0x10FFFF, bytes(0xF4, 0x8F, 0xBF, 0xBF) },
    }
    for i = 1, #boundaries do
        local cp, s = boundaries[i][1], boundaries[i][2]
        test(("boundary U+%04X"):format(cp), function()
            cpsEq(charigo.decode(s, "utf-8"), { cp })
            eq(charigo.encode({ cp }, "utf-8"), s)
            truthy(charigo.valid(s, "utf-8"))
        end)
    end

    local rejections = {
        { "lead C0", bytes(0xC0, 0x80) },
        { "lead C1", bytes(0xC1, 0xBF) },
        { "lead F5", bytes(0xF5, 0x80, 0x80, 0x80) },
        { "lead FF", bytes(0xFF) },
        { "bare continuation", bytes(0x80) },
        { "bare continuation BF", bytes(0xBF) },
        { "overlong E0 80", bytes(0xE0, 0x80, 0x80) },
        { "overlong E0 9F", bytes(0xE0, 0x9F, 0xBF) },
        { "overlong F0 80", bytes(0xF0, 0x80, 0x80, 0x80) },
        { "overlong F0 8F", bytes(0xF0, 0x8F, 0xBF, 0xBF) },
        { "surrogate ED A0", bytes(0xED, 0xA0, 0x80) },
        { "surrogate ED BF", bytes(0xED, 0xBF, 0xBF) },
        { "above 10FFFF F4 90", bytes(0xF4, 0x90, 0x80, 0x80) },
        { "truncated 2-byte", bytes(0xC3) },
        { "truncated 3-byte after 1", bytes(0xE2) },
        { "truncated 3-byte after 2", bytes(0xE2, 0x82) },
        { "truncated 4-byte after 3", bytes(0xF0, 0x9F, 0x98) },
        { "lead then ASCII", bytes(0xC3, 0x41) },
    }
    for i = 1, #rejections do
        local name, bad = rejections[i][1], rejections[i][2]
        test("reject " .. name .. " at byte 3", function()
            local s = "ab" .. bad
            local ok, pos = charigo.valid(s, "utf-8")
            eq(ok, false)
            eq(pos, 3)
            raises(function() charigo.decode(s, "utf-8") end, "invalid utf-8 at byte 3")
        end)
    end

    test("position after multi-byte characters", function()
        local s = bytes(0xC3, 0xA9) .. bytes(0xE2, 0x82, 0xAC) .. "x" .. bytes(0xFF)
        local ok, pos = charigo.valid(s, "utf-8")
        eq(ok, false)
        eq(pos, 7)
    end)

    test("position after a long ASCII run", function()
        local s = ("a"):rep(10000) .. bytes(0xC0)
        local ok, pos = charigo.valid(s, "utf-8")
        eq(ok, false)
        eq(pos, 10001)
        raises(function() charigo.decode(s, "utf-8") end, "at byte 10001")
    end)

    test("valid returns true on good input", function()
        eq(charigo.valid("", "utf-8"), true)
        eq(charigo.valid("plain", "utf-8"), true)
        eq(charigo.valid(bytes(0xF4, 0x8F, 0xBF, 0xBF), "utf-8"), true)
    end)

    test("strict is the default policy", function()
        raises(function() charigo.decode(bytes(0xFF), "utf-8") end, "charigo: invalid utf-8 at byte 1")
        raises(function() charigo.decode(bytes(0xFF), "utf-8", {}) end, "invalid utf-8")
    end)

    test("replace uses one U+FFFD per maximal subpart", function()
        local function rep(s) return charigo.decode(s, "utf-8", { errors = "replace" }) end
        cpsEq(rep(bytes(0xF0, 0x9F, 0x98)), { 0xFFFD })
        cpsEq(rep(bytes(0xC0, 0x80)), { 0xFFFD, 0xFFFD })
        cpsEq(rep(bytes(0xE0, 0x80, 0x80)), { 0xFFFD, 0xFFFD, 0xFFFD })
        cpsEq(rep(bytes(0xED, 0xA0, 0x80)), { 0xFFFD, 0xFFFD, 0xFFFD })
        cpsEq(rep(bytes(0xF4, 0x90, 0x80, 0x80)), { 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD })
        cpsEq(rep(bytes(0xE2, 0x82, 0x41)), { 0xFFFD, 0x41 })
        cpsEq(rep(bytes(0xF0, 0x9F, 0x98, 0x41)), { 0xFFFD, 0x41 })
        cpsEq(rep("a" .. bytes(0xFF) .. "b"), { 0x61, 0xFFFD, 0x62 })
        cpsEq(rep(bytes(0xC3)), { 0xFFFD })
    end)

    test("skip drops invalid input", function()
        local function skip(s) return charigo.decode(s, "utf-8", { errors = "skip" }) end
        cpsEq(skip("a" .. bytes(0xC0, 0x80) .. "b"), { 0x61, 0x62 })
        cpsEq(skip("a" .. bytes(0xF0, 0x9F, 0x98)), { 0x61 })
        cpsEq(skip(bytes(0xE2, 0x82, 0x41)), { 0x41 })
    end)

    test("unknown errors policy raises", function()
        raises(function() charigo.decode("a", "utf-8", { errors = "ignore" }) end, "unknown errors policy 'ignore'")
        raises(function() charigo.encode({ 65 }, "utf-8", { errors = "ignore" }) end, "unknown errors policy")
    end)

    test("encode rejects invalid code points", function()
        local bad = { -1, 0x110000, 0xD800, 0xDFFF, 1.5, "x", 0 / 0, math.huge }
        for i = 1, #bad do
            raises(function() charigo.encode({ 65, bad[i] }, "utf-8") end, "charigo: invalid code point at index 2")
        end
    end)

    test("encode accepts the edges of the valid range", function()
        eq(charigo.encode({ 0, 0xD7FF, 0xE000 }, "utf-8"), bytes(0, 0xED, 0x9F, 0xBF, 0xEE, 0x80, 0x80))
    end)

    test("encode replace and skip", function()
        eq(charigo.encode({ 65, 0xD800, 66 }, "utf-8", { errors = "replace" }), "A" .. bytes(0xEF, 0xBF, 0xBD) .. "B")
        eq(charigo.encode({ 65, 0x110000, 66 }, "utf-8", { errors = "skip" }), "AB")
    end)

    test("round trip", function()
        local sample = { 0x41, 0xE9, 0x20AC, 0x1F600, 0x10FFFF, 0x7F, 0x80, 0x7FF, 0x800, 0xFFFF, 0x10000, 0 }
        cpsEq(charigo.decode(charigo.encode(sample, "utf-8"), "utf-8"), sample)
    end)

    test("round trip across chunk boundaries", function()
        local sample = {}
        for i = 1, 10000 do sample[i] = (i % 3 == 0) and 0x20AC or 0x41 end
        local s = charigo.encode(sample, "utf-8")
        cpsEq(charigo.decode(s, "utf-8"), sample)
        local ascii = ("z"):rep(9000)
        eq(#charigo.decode(ascii, "utf-8"), 9000)
        eq(charigo.encode(charigo.decode(ascii, "utf-8"), "utf-8"), ascii)
    end)

    test("encoding names are case-insensitive", function()
        local names = { "utf-8", "UTF-8", "utf8", "UTF8", "Utf-8" }
        for i = 1, #names do
            cpsEq(charigo.decode("a", names[i]), { 97 })
            eq(charigo.valid("a", names[i]), true)
            eq(charigo.encode({ 97 }, names[i]), "a")
        end
    end)

    test("unknown encoding raises", function()
        raises(function() charigo.decode("a", "latin1") end, "charigo: unknown encoding 'latin1'")
        raises(function() charigo.encode({ 97 }, "nope") end, "charigo: unknown encoding 'nope'")
        raises(function() charigo.valid("a") end, "charigo: unknown encoding 'nil'")
    end)
end
