return function(env)
    local test, eq, truthy, falsy, charigo = env.test, env.eq, env.truthy, env.falsy, env.charigo

    local u8 = charigo._utf8
    local unpackFn = table.unpack or unpack

    local function newRng(seed)
        local state = seed
        return function(n)
            state = (state * 16807) % 2147483647
            return state % n
        end
    end

    local INTERESTING = {
        0x00, 0x41, 0x7F, 0x80, 0x8F, 0x90, 0x9F, 0xA0, 0xBF,
        0xC0, 0xC1, 0xC2, 0xDF, 0xE0, 0xED, 0xEF, 0xF0, 0xF4, 0xF5, 0xFF,
    }

    local function randomBytes(rnd, maxLen)
        local n = rnd(maxLen + 1)
        local t = {}
        for i = 1, n do
            if rnd(3) == 0 then
                t[i] = INTERESTING[rnd(#INTERESTING) + 1]
            else
                t[i] = rnd(256)
            end
        end
        return string.char(unpackFn(t))
    end

    local CP1252_EXTRA = { 0x20AC, 0x201A, 0x0192, 0x2026, 0x2122, 0x0152, 0x017E, 0x0081, 0x009D }

    local function randomCp(rnd)
        local k = rnd(10)
        if k <= 2 then return rnd(0x80) end
        if k == 3 then return 0x80 + rnd(0x80) end
        if k == 4 then return 0x100 + rnd(0x700) end
        if k == 5 then return CP1252_EXTRA[rnd(#CP1252_EXTRA) + 1] end
        if k == 6 then return 0x800 + rnd(0xD800 - 0x800) end
        if k == 7 then return 0xE000 + rnd(0x10000 - 0xE000) end
        return 0x10000 + rnd(0x100000)
    end

    local function randomValid(rnd, maxLen)
        local n = rnd(maxLen + 1)
        local t = {}
        for i = 1, n do t[i] = randomCp(rnd) end
        return charigo.encode(t, "utf-8")
    end

    local TARGETS = {
        { "latin1" },
        { "cp1252" },
        { "utf-16le" },
        { "utf-16be" },
        { "utf-16le", true },
        { "utf-16be", true },
    }
    local MODES = { "strict", "replace", "skip" }

    local function outcome(fn)
        local ok, res = pcall(fn)
        return ok, res
    end

    local function checkEquivalent(s)
        for m = 1, #MODES do
            for t = 1, #TARGETS do
                local target, bom = TARGETS[t][1], TARGETS[t][2]
                local opts = { errors = MODES[m], bom = bom }
                local okA, a = outcome(function() return charigo.convert(s, "utf-8", target, opts) end)
                local okB, b = outcome(function()
                    return charigo.encode(charigo.decode(s, "utf-8", opts), target, opts)
                end)
                if okA ~= okB or a ~= b then
                    error(("mismatch for %q -> %s%s (%s): %s / %s"):format(
                        s, target, bom and "+bom" or "", MODES[m], tostring(a), tostring(b)), 0)
                end
            end
        end
    end

    test("perf: convert equals decode then encode on random bytes", function()
        local rnd = newRng(20261112)
        for _ = 1, 1500 do checkEquivalent(randomBytes(rnd, 24)) end
    end)

    test("perf: convert equals decode then encode on valid utf-8", function()
        local rnd = newRng(77031)
        for _ = 1, 1500 do checkEquivalent(randomValid(rnd, 24)) end
    end)

    test("perf: convert equals decode then encode on edge strings", function()
        checkEquivalent("")
        checkEquivalent("plain ascii\n\0with nul")
        checkEquivalent("\0")
        checkEquivalent("caf\195\169 \226\130\172 \240\159\152\128 \0 end")
        checkEquivalent("\237\160\128")
        checkEquivalent("\192\128abc")
        checkEquivalent("ok \226\130")
    end)

    local INVALID = {
        "\237\160\128", "\237\191\191\237\160\128",
        "\192\128", "\193\191", "\224\128\128", "\224\159\191",
        "\240\128\128\128", "\240\143\191\191",
        "\244\144\128\128", "\245\128\128\128", "\248\136\128\128\128",
        "\226\130", "\240\159\152", "a\195", "\128", "\191abc", "\255",
    }

    local VALID = {
        "", "abc", "\0", "\194\128", "\223\191", "\224\160\128", "\237\159\191",
        "\238\128\128", "\239\191\189", "\240\144\128\128", "\244\143\191\191",
    }

    test("perf: valid matches the pure Lua scan on listed strings", function()
        for i = 1, #INVALID do
            local ok, pos = charigo.valid(INVALID[i], "utf-8")
            local lok, lpos = u8._validLua(INVALID[i])
            falsy(ok)
            eq(ok, lok)
            eq(pos, lpos)
        end
        for i = 1, #VALID do
            truthy(charigo.valid(VALID[i], "utf-8"))
            truthy(u8._validLua(VALID[i]))
        end
    end)

    test("perf: valid matches the pure Lua scan on the fuzz corpus", function()
        local rnd = newRng(424242)
        for round = 1, 3000 do
            local s
            if round % 2 == 0 then s = randomBytes(rnd, 24) else s = randomValid(rnd, 24) end
            if round % 5 == 0 and #s > 0 then s = s:sub(1, #s - 1) end
            local ok, pos = charigo.valid(s, "utf-8")
            local lok, lpos = u8._validLua(s)
            if ok ~= lok or pos ~= lpos then
                error(("valid mismatch for %q: %s,%s / %s,%s"):format(
                    s, tostring(ok), tostring(pos), tostring(lok), tostring(lpos)), 0)
            end
        end
    end)

    test("perf: memo cap keeps results right with more than 5000 distinct chars", function()
        local cps = {}
        for cp = 0x80, 0x80 + 5400 do cps[#cps + 1] = cp end
        local s = charigo.encode(cps, "utf-8")
        for _, target in ipairs({ "utf-16le", "utf-16be" }) do
            local expected = charigo.encode(cps, target)
            eq(charigo.convert(s, "utf-8", target), expected)
            eq(charigo.convert(s, "utf-8", target), expected)
        end
        local mixed = charigo.encode({ 0x41, 0x1F600, 0x20AC, 0x80 + 5400, 0x42 }, "utf-8")
        eq(charigo.convert(mixed, "utf-8", "utf-16le"),
            charigo.encode({ 0x41, 0x1F600, 0x20AC, 0x80 + 5400, 0x42 }, "utf-16le"))
    end)

    local SOURCES = { "utf-16le", "utf-16be", "utf-16" }

    local function unitsToBytes(units, be)
        local t = {}
        for i = 1, #units do
            local u = units[i]
            local hi, lo = math.floor(u / 256), u % 256
            if be then
                t[#t + 1], t[#t + 2] = hi, lo
            else
                t[#t + 1], t[#t + 2] = lo, hi
            end
        end
        return string.char(unpackFn(t))
    end

    local function randomUnits(rnd, maxLen, allowBroken)
        local n = rnd(maxLen + 1)
        local units = {}
        for _ = 1, n do
            local k = rnd(12)
            if k <= 2 then
                units[#units + 1] = rnd(0x80)
            elseif k == 3 then
                units[#units + 1] = 0x00D8 + rnd(8)
            elseif k == 4 then
                units[#units + 1] = ({ 0xD7FF, 0xE000, 0xD7FE, 0xE001, 0xFFFD, 0xFFFF })[rnd(6) + 1]
            elseif k == 5 then
                units[#units + 1] = 0x100 + rnd(0x700)
            elseif k <= 7 then
                units[#units + 1] = 0x800 + rnd(0xD800 - 0x800)
            elseif k == 8 then
                units[#units + 1] = 0xE000 + rnd(0x2000)
            elseif k <= 10 or not allowBroken then
                local v = rnd(0x100000)
                units[#units + 1] = 0xD800 + math.floor(v / 1024)
                units[#units + 1] = 0xDC00 + v % 1024
            else
                units[#units + 1] = 0xD800 + rnd(0x800)
            end
        end
        return units
    end

    local function checkDecodeEquivalent(s)
        for m = 1, #MODES do
            for t = 1, #SOURCES do
                local source = SOURCES[t]
                local opts = { errors = MODES[m] }
                local okA, a = outcome(function() return charigo.convert(s, source, "utf-8", opts) end)
                local okB, b = outcome(function()
                    return charigo.encode(charigo.decode(s, source, opts), "utf-8", opts)
                end)
                if okA ~= okB or a ~= b then
                    error(("mismatch for %q %s -> utf-8 (%s): %s / %s"):format(
                        s, source, MODES[m], tostring(a), tostring(b)), 0)
                end
            end
        end
    end

    local function withBom(s, be)
        if be then return string.char(0xFE, 0xFF) .. s end
        return string.char(0xFF, 0xFE) .. s
    end

    local function bytes(...)
        return string.char(...)
    end

    test("perf: utf-16 to utf-8 equals decode then encode on random bytes", function()
        local rnd = newRng(31337)
        for _ = 1, 1200 do checkDecodeEquivalent(randomBytes(rnd, 24)) end
    end)

    test("perf: utf-16 to utf-8 equals decode then encode on random valid units", function()
        local rnd = newRng(8675309)
        for _ = 1, 1200 do
            local units = randomUnits(rnd, 24, false)
            local le, be = unitsToBytes(units, false), unitsToBytes(units, true)
            checkDecodeEquivalent(le)
            checkDecodeEquivalent(be)
            checkDecodeEquivalent(withBom(le, false))
            checkDecodeEquivalent(withBom(be, true))
            checkDecodeEquivalent(withBom(le, true))
            checkDecodeEquivalent(withBom(be, false))
        end
    end)

    test("perf: utf-16 to utf-8 equals decode then encode on broken units and odd lengths", function()
        local rnd = newRng(1234577)
        for round = 1, 1200 do
            local units = randomUnits(rnd, 24, true)
            local be = round % 2 == 0
            local s = unitsToBytes(units, be)
            if round % 3 == 0 then s = withBom(s, be) end
            if round % 4 == 0 and #s > 0 then s = s:sub(1, #s - 1) end
            if round % 7 == 0 then s = s .. bytes(65) end
            checkDecodeEquivalent(s)
        end
    end)

    test("perf: utf-16 to utf-8 equals decode then encode on edge strings", function()
        local edges = {
            "", bytes(65), bytes(65, 0), bytes(0, 65), bytes(0, 0),
            bytes(0xFF, 0xFE), bytes(0xFE, 0xFF), bytes(0xFF, 0xFE, 0), bytes(0xFF, 0xFE, 65, 0),
            bytes(0xFE, 0xFF, 0, 65), bytes(0xFF, 0xFE, 0xFE, 0xFF), bytes(0xFE, 0xFF, 0xFF, 0xFE),
            bytes(0xD8, 0), bytes(0, 0xD8), bytes(0, 0xD8, 0, 0xDC), bytes(0xD8, 0, 0xDC, 0),
            bytes(0xFF, 0xFE, 0x3D, 0xD8, 0, 0xDE), bytes(0xFE, 0xFF, 0xD8, 0x3D, 0xDE, 0),
            bytes(0xFF, 0x7F, 0, 0x80), bytes(0xFF, 0xD7, 0, 0xE0), bytes(0xD7, 0xFF, 0xE0, 0),
            bytes(0xD8, 0, 0xD8, 0, 0xDC, 0), bytes(0xDC, 0, 0xD8, 0),
        }
        for i = 1, #edges do checkDecodeEquivalent(edges[i]) end
    end)

    test("perf: utf-16 to utf-8 memo cap keeps results right with more than 5000 distinct units", function()
        local cps = {}
        for cp = 0x80, 0x80 + 6000 do cps[#cps + 1] = cp end
        local expected = charigo.encode(cps, "utf-8")
        for _, source in ipairs({ "utf-16le", "utf-16be", "utf-16" }) do
            local s = charigo.encode(cps, source == "utf-16be" and "utf-16be" or "utf-16le")
            if source == "utf-16" then s = withBom(s, false) end
            eq(charigo.convert(s, source, "utf-8"), expected)
            eq(charigo.convert(s, source, "utf-8"), expected)
        end
        local mixed = { 0x41, 0x20AC, 0x80 + 6000, 0x7FF, 0x800, 0x42 }
        eq(charigo.convert(charigo.encode(mixed, "utf-16be"), "utf-16be", "utf-8"),
            charigo.encode(mixed, "utf-8"))
    end)

    test("perf: utf-16 to utf-8 stays right after a strict error", function()
        local bad = bytes(65, 0, 0, 0xD8, 66, 0)
        falsy((pcall(charigo.convert, bad, "utf-16le", "utf-8")))
        eq(charigo.convert(bytes(65, 0, 66, 0), "utf-16le", "utf-8"), "AB")
        eq(charigo.convert(bad, "utf-16le", "utf-8", { errors = "replace" }), "A" .. bytes(0xEF, 0xBF, 0xBD) .. "B")
    end)
end
