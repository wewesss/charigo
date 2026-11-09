return function(env)
    local test, eq, truthy, falsy, charigo = env.test, env.eq, env.truthy, env.falsy, env.charigo

    local function newRng(seed)
        local state = seed
        return function(n)
            state = (state * 16807) % 2147483647
            return state % n
        end
    end

    local unpackFn = table.unpack or unpack

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

    local function randomCp(rnd)
        local k = rnd(8)
        if k == 0 then return rnd(0x80) end
        if k == 1 then return 0x80 + rnd(0x780) end
        if k == 2 then return 0x800 + rnd(0xD800 - 0x800) end
        if k == 3 then return 0xE000 + rnd(0x10000 - 0xE000) end
        if k == 4 then return 0x10000 + rnd(0x100000) end
        if k == 5 then return 0xD800 + rnd(0x800) end
        if k == 6 then return 0x110000 + rnd(0x1000) end
        return rnd(0x110000)
    end

    local function validCps(rnd, maxLen)
        local n = rnd(maxLen + 1)
        local t = {}
        for i = 1, n do
            local cp = randomCp(rnd)
            while cp >= 0xD800 and cp <= 0xDFFF or cp > 0x10FFFF do cp = randomCp(rnd) end
            t[i] = cp
        end
        return t
    end

    local function anyCps(rnd, maxLen)
        local n = rnd(maxLen + 1)
        local t = {}
        for i = 1, n do t[i] = randomCp(rnd) end
        return t
    end

    local function sameCps(a, b)
        if #a ~= #b then return false end
        for i = 1, #a do
            if a[i] ~= b[i] then return false end
        end
        return true
    end

    local ROUNDS = 2000
    local policies = { "replace", "skip" }

    test("fuzz utf-8 decode strict errors or round-trips, valid agrees", function()
        local rnd = newRng(20261109)
        for _ = 1, ROUNDS do
            local s = randomBytes(rnd, 24)
            local ok, res = pcall(charigo.decode, s, "utf-8")
            local isValid, pos = charigo.valid(s, "utf-8")
            eq(isValid, ok)
            if ok then
                eq(charigo.encode(res, "utf-8"), s)
            else
                truthy(tostring(res):match("^charigo: invalid utf%-8 at byte %d+$"))
                truthy(pos >= 1 and pos <= #s)
                falsy(isValid)
            end
        end
    end)

    test("fuzz utf-8 replace and skip never error and yield valid output", function()
        local rnd = newRng(777)
        for _ = 1, ROUNDS do
            local s = randomBytes(rnd, 24)
            for p = 1, #policies do
                local cps = charigo.decode(s, "utf-8", { errors = policies[p] })
                local out = charigo.encode(cps, "utf-8")
                truthy(charigo.valid(out, "utf-8"))
                local viaConvert = charigo.convert(s, "utf-8", "utf-8", { errors = policies[p] })
                truthy(charigo.valid(viaConvert, "utf-8"))
                eq(viaConvert, out)
            end
        end
    end)

    test("fuzz utf-8 encode of arbitrary code points", function()
        local rnd = newRng(4242)
        for _ = 1, ROUNDS do
            local cps = anyCps(rnd, 16)
            local ok, res = pcall(charigo.encode, cps, "utf-8")
            if ok then
                truthy(sameCps(charigo.decode(res, "utf-8"), cps))
            else
                truthy(tostring(res):match("^charigo: invalid code point at index %d+$"))
            end
            for p = 1, #policies do
                local out = charigo.encode(cps, "utf-8", { errors = policies[p] })
                truthy(charigo.valid(out, "utf-8"))
            end
        end
    end)

    test("fuzz utf-16 decode strict errors or round-trips, valid agrees", function()
        local rnd = newRng(31337)
        local encs = { "utf-16le", "utf-16be" }
        for _ = 1, ROUNDS do
            local s = randomBytes(rnd, 24)
            for e = 1, #encs do
                local ok, res = pcall(charigo.decode, s, encs[e])
                eq(charigo.valid(s, encs[e]), ok)
                if ok then
                    truthy(sameCps(charigo.decode(charigo.encode(res, encs[e]), encs[e]), res))
                else
                    truthy(tostring(res):match("^charigo: invalid utf%-16 at byte %d+$"))
                end
                for p = 1, #policies do
                    local cps = charigo.decode(s, encs[e], { errors = policies[p] })
                    local out = charigo.encode(cps, encs[e])
                    truthy(charigo.valid(out, encs[e]))
                end
            end
        end
    end)

    test("fuzz utf-16 round trips with and without BOM", function()
        local rnd = newRng(9001)
        for _ = 1, ROUNDS do
            local cps = validCps(rnd, 16)
            for _, enc in ipairs({ "utf-16le", "utf-16be", "utf-16" }) do
                truthy(sameCps(charigo.decode(charigo.encode(cps, enc), enc), cps))
                truthy(sameCps(charigo.decode(charigo.encode(cps, enc, { bom = true }), enc), cps))
            end
            local arbitrary = anyCps(rnd, 16)
            for p = 1, #policies do
                local out = charigo.encode(arbitrary, "utf-16le", { errors = policies[p] })
                truthy(charigo.valid(out, "utf-16le"))
            end
        end
    end)

    test("fuzz single-byte sets round-trip through utf-8 and code points", function()
        local rnd = newRng(1252)
        for _ = 1, ROUNDS do
            local s = randomBytes(rnd, 24)
            for _, enc in ipairs({ "latin1", "cp1252" }) do
                local u = charigo.convert(s, enc, "utf-8")
                truthy(charigo.valid(u, "utf-8"))
                eq(charigo.convert(u, "utf-8", enc), s)
                eq(charigo.encode(charigo.decode(s, enc), enc), s)
                eq(charigo.encode(charigo.decode(s, enc), "utf-8"), u)
            end
        end
    end)

    test("fuzz single-byte encode policies on arbitrary code points", function()
        local rnd = newRng(88)
        for _ = 1, ROUNDS do
            local cps = anyCps(rnd, 12)
            for _, enc in ipairs({ "latin1", "cp1252" }) do
                local ok, res = pcall(charigo.encode, cps, enc)
                if ok then
                    truthy(sameCps(charigo.decode(res, enc), cps))
                else
                    truthy(tostring(res):match("^charigo: cannot encode U%+%x+ in %w+ at index %d+$")
                        or tostring(res):match("^charigo: invalid code point at index %d+$"))
                end
                local replaced = charigo.encode(cps, enc, { errors = "replace" })
                local skipped = charigo.encode(cps, enc, { errors = "skip" })
                truthy(#skipped <= #replaced)
                eq(#replaced, #cps)
            end
        end
    end)

    test("fuzz convert equals converter", function()
        local rnd = newRng(5150)
        local encs = { "utf-8", "utf-16le", "utf-16be", "utf-16", "latin1", "cp1252" }
        local modes = { "strict", "replace", "skip" }
        for _ = 1, 600 do
            local s = randomBytes(rnd, 20)
            local from = encs[rnd(#encs) + 1]
            local to = encs[rnd(#encs) + 1]
            local opts = { errors = modes[rnd(#modes) + 1], bom = rnd(2) == 0 }
            local fn = charigo.converter(from, to, opts)
            local ok1, r1 = pcall(charigo.convert, s, from, to, opts)
            local ok2, r2 = pcall(fn, s)
            eq(ok1, ok2)
            eq(r1, r2)
            local ok3, r3 = pcall(charigo.convert, s, from, to, opts)
            eq(ok3, ok1)
            eq(r3, r1)
        end
    end)
end
