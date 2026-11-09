return function(env)
    local test, eq, raises, charigo = env.test, env.eq, env.raises, env.charigo
    local char = string.char

    local encs = { "utf-8", "utf-16le", "utf-16be", "latin1", "cp1252" }

    local function representable(name, cps)
        return (pcall(charigo.encode, cps, name))
    end

    local samples = {
        { 0x48, 0x65, 0x6C, 0x6C, 0x6F },
        { 0x48, 0xE9, 0xE0, 0xFC, 0xFF },
        { 0x20AC, 0x41, 0x2122, 0x201C, 0x201D },
        { 0x1F600, 0x41, 0x10FFFF, 0x10000 },
        { 0x80, 0x9F, 0xA0, 0xFE },
        {},
    }

    for fi = 1, #encs do
        for ti = 1, #encs do
            local from, to = encs[fi], encs[ti]
            test("pair " .. from .. " -> " .. to .. " round trips representable samples", function()
                local conv = charigo.converter(from, to)
                for _, cps in ipairs(samples) do
                    if representable(from, cps) and representable(to, cps) then
                        local src = charigo.encode(cps, from)
                        local out = conv(src)
                        eq(out, charigo.encode(cps, to))
                        eq(charigo.convert(src, from, to), out)
                        eq(charigo.convert(out, to, from), src)
                    end
                end
            end)
        end
    end

    test("euro sign utf-8 -> cp1252 is 0x80", function()
        eq(charigo.convert("\226\130\172", "utf-8", "cp1252"), char(0x80))
        eq(charigo.convert(char(0x80), "cp1252", "utf-8"), "\226\130\172")
    end)

    test("euro sign utf-8 -> latin1: strict errors, replace gives ?, skip drops", function()
        local euro = "a\226\130\172b"
        raises(function() charigo.convert(euro, "utf-8", "latin1") end,
            "charigo: cannot encode U+20AC in latin1 at index 2")
        eq(charigo.convert(euro, "utf-8", "latin1", { errors = "replace" }), "a?b")
        eq(charigo.convert(euro, "utf-8", "latin1", { errors = "skip" }), "ab")
    end)

    test("unmappable target from utf-16: index is the code point index", function()
        local src = charigo.encode({ 0x41, 0x1F600 }, "utf-16le")
        raises(function() charigo.convert(src, "utf-16le", "cp1252") end,
            "cannot encode U+1F600 in cp1252 at index 2")
        eq(charigo.convert(src, "utf-16le", "cp1252", { errors = "replace" }), "A?")
    end)

    test("strict is the default policy", function()
        raises(function() charigo.convert("\255", "utf-8", "utf-16le") end, "invalid utf-8 at byte 1")
        raises(function() charigo.convert("\255", "utf-8", "utf-8", { errors = "strict" }) end,
            "invalid utf-8 at byte 1")
    end)

    local bad = "ab\255cd\226\130"

    test("invalid utf-8 source: strict reports the source byte position", function()
        for i = 1, #encs do
            local ok, err = pcall(charigo.convert, bad, "utf-8", encs[i])
            eq(ok, false)
            eq(err, "charigo: invalid utf-8 at byte 3")
        end
    end)

    test("invalid utf-8 source: replace", function()
        eq(charigo.convert(bad, "utf-8", "utf-8", { errors = "replace" }), "ab\239\191\189cd\239\191\189")
        eq(charigo.convert(bad, "utf-8", "utf-16le", { errors = "replace" }),
            charigo.encode({ 0x61, 0x62, 0xFFFD, 0x63, 0x64, 0xFFFD }, "utf-16le"))
        eq(charigo.convert(bad, "utf-8", "latin1", { errors = "replace" }), "ab?cd?")
        eq(charigo.convert(bad, "utf-8", "cp1252", { errors = "replace" }), "ab?cd?")
    end)

    test("invalid utf-8 source: skip", function()
        eq(charigo.convert(bad, "utf-8", "utf-8", { errors = "skip" }), "abcd")
        eq(charigo.convert(bad, "utf-8", "utf-16be", { errors = "skip" }),
            charigo.encode({ 0x61, 0x62, 0x63, 0x64 }, "utf-16be"))
        eq(charigo.convert(bad, "utf-8", "latin1", { errors = "skip" }), "abcd")
    end)

    test("invalid utf-16 source reports its byte position", function()
        local src = char(0x41, 0x00, 0x00, 0xDC)
        raises(function() charigo.convert(src, "utf-16le", "utf-8") end, "charigo: invalid utf-16 at byte 3")
        eq(charigo.convert(src, "utf-16le", "utf-8", { errors = "replace" }), "A\239\191\189")
        eq(charigo.convert(src, "utf-16le", "utf-8", { errors = "skip" }), "A")
    end)

    test("same-encoding fast path", function()
        local s = "h\195\169llo \226\130\172"
        eq(charigo.convert(s, "utf-8", "utf8"), s)
        eq(charigo.convert(s, "UTF-8", "utf-8", { errors = "skip" }), s)
        eq(charigo.convert("\233\255", "latin1", "iso-8859-1"), "\233\255")
        eq(charigo.convert(char(0x80, 0x81), "cp1252", "windows-1252"), char(0x80, 0x81))
        raises(function() charigo.convert("a\192", "utf-8", "utf-8") end, "invalid utf-8 at byte 2")
    end)

    test("same-encoding replace and skip normalise", function()
        eq(charigo.convert("a\192b", "utf-8", "utf-8", { errors = "replace" }), "a\239\191\189b")
        eq(charigo.convert("a\192b", "utf-8", "utf-8", { errors = "skip" }), "ab")
    end)

    test("utf-16 to utf-16 strips and re-adds BOMs per option", function()
        local src = char(0xFF, 0xFE, 0x41, 0x00)
        eq(charigo.convert(src, "utf-16le", "utf-16le"), char(0x41, 0x00))
        eq(charigo.convert(src, "utf-16le", "utf-16le", { bom = true }), src)
        eq(charigo.convert(src, "utf-16le", "utf-16be", { bom = true }), char(0xFE, 0xFF, 0x00, 0x41))
        eq(charigo.convert("A", "utf-8", "utf-16"), src)
    end)

    test("opts.bom reaches utf-16 targets through convert", function()
        eq(charigo.convert("A", "utf-8", "utf-16le", { bom = true }), char(0xFF, 0xFE, 0x41, 0x00))
        eq(charigo.convert("A", "utf-8", "utf-16le"), char(0x41, 0x00))
        eq(charigo.convert("A", "utf-8", "utf-16le", { bom = true }), char(0xFF, 0xFE, 0x41, 0x00))
    end)

    test("converter returns a reusable function", function()
        local conv = charigo.converter("latin1", "utf-8")
        eq(type(conv), "function")
        eq(conv("\233"), "\195\169")
        eq(conv("\233"), "\195\169")
        eq(conv(""), "")
    end)

    test("convert and converter agree on a sample matrix", function()
        local inputs = {
            "", "plain", "h\195\169llo", "\226\130\172", "\240\159\152\128", "a\255b", "\237\160\128", "\226\130",
        }
        local policies = { "strict", "replace", "skip" }
        for fi = 1, #encs do
            for ti = 1, #encs do
                for pi = 1, #policies do
                    local from, to = encs[fi], encs[ti]
                    local opts = { errors = policies[pi] }
                    local conv = charigo.converter(from, to, opts)
                    for k = 1, #inputs do
                        local s = inputs[k]
                        local ok1, r1 = pcall(conv, s)
                        local ok2, r2 = pcall(charigo.convert, s, from, to, opts)
                        local ok3, r3 = pcall(charigo.convert, s, from, to, opts)
                        eq(ok1, ok2)
                        eq(ok1, ok3)
                        eq(r1, r2)
                        eq(r1, r3)
                    end
                end
            end
        end
    end)

    test("convert cache does not mix policies or bom", function()
        local euro = "\226\130\172"
        eq(charigo.convert(euro, "utf-8", "latin1", { errors = "replace" }), "?")
        eq(charigo.convert(euro, "utf-8", "latin1", { errors = "skip" }), "")
        raises(function() charigo.convert(euro, "utf-8", "latin1") end, "cannot encode")
        eq(charigo.convert("", "utf-8", "utf-16le", { bom = true }), char(0xFF, 0xFE))
        eq(charigo.convert("", "utf-8", "utf-16le"), "")
    end)

    test("unknown encodings and policies", function()
        raises(function() charigo.convert("a", "klingon", "utf-8") end, "charigo: unknown encoding 'klingon'")
        raises(function() charigo.converter("utf-8", "klingon") end, "charigo: unknown encoding 'klingon'")
        raises(function() charigo.converter(nil, "utf-8") end, "unknown encoding 'nil'")
        raises(function() charigo.convert("a", "utf-8", "latin1", { errors = "nope" }) end,
            "unknown errors policy 'nope'")
        raises(function() charigo.converter("utf-8", "latin1", { errors = "nope" }) end,
            "unknown errors policy 'nope'")
    end)

    test("large conversion across chunks", function()
        local cps = {}
        for i = 1, 20000 do cps[i] = 0x20 + i % 0x5000 end
        local u8s = charigo.encode(cps, "utf-8")
        local u16 = charigo.convert(u8s, "utf-8", "utf-16be")
        eq(charigo.convert(u16, "utf-16be", "utf-8"), u8s)
    end)
end
