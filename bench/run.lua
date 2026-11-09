local smoke = false
local dist = false
for _, a in ipairs(arg or {}) do
    if a == "--smoke" then smoke = true end
    if a == "dist" then dist = true end
end

local charigo
if dist then
    charigo = dofile("dist/charigo.lua")
else
    package.path = "./?.lua;./?/init.lua;" .. package.path
    charigo = require("charigo")
end

local TARGET = smoke and 2048 or 1024 * 1024
local REPEAT = smoke and 1 or 5

local function fill(unit)
    local parts, n, size = {}, 0, 0
    while size < TARGET do
        n = n + 1
        parts[n] = unit
        size = size + #unit
    end
    return table.concat(parts)
end

local inputs = {
    ascii = fill("The quick brown fox jumps over the lazy dog. 0123456789\n"),
    french = fill("L'\195\169t\195\169 dernier, \195\160 Gen\195\168ve, le ma\195\174tre a d\195\169pos\195\169 son \197\147uvre \195\160 l'\195\169cole. "),
    emoji = fill("Hello \240\159\152\128 world \226\130\172 caf\195\169 \240\159\154\128 \230\151\165\230\156\172\232\170\158\n"),
}
local order = { "ascii", "french", "emoji" }

local function best(fn)
    local top = math.huge
    for _ = 1, REPEAT do
        local t0 = os.clock()
        fn()
        local dt = os.clock() - t0
        if dt < top then top = dt end
    end
    if top <= 0 then top = 1e-9 end
    return top
end

local function report(scenario, kind, bytes, seconds)
    print(("%-34s %-7s %9.1f MB/s"):format(scenario, kind, bytes / 1048576 / seconds))
end

local function run(name, kind, s, fn)
    local out = fn(s)
    assert(type(out) == "string")
    report(name, kind, #s, best(function() fn(s) end))
end

print(("charigo %s, %s, input ~%d bytes%s"):format(
    charigo._VERSION, rawget(_G, "jit") and jit.version or _VERSION, TARGET, smoke and " (smoke)" or ""))

local latin = {
    ascii = inputs.ascii,
    french = charigo.convert(inputs.french, "utf-8", "cp1252"),
}
local u16 = {}
for i = 1, #order do
    u16[order[i]] = charigo.convert(inputs[order[i]], "utf-8", "utf-16le")
end

local scenarios = {
    { "convert utf-8 -> cp1252", "utf-8", "cp1252", { "ascii", "french" }, inputs },
    { "convert cp1252 -> utf-8", "cp1252", "utf-8", { "ascii", "french" }, latin },
    { "convert utf-8 -> utf-16le", "utf-8", "utf-16le", order, inputs },
    { "convert utf-16le -> utf-8", "utf-16le", "utf-8", order, u16 },
}

for _, sc in ipairs(scenarios) do
    local name, from, to, kinds, data = sc[1], sc[2], sc[3], sc[4], sc[5]
    for _, kind in ipairs(kinds) do
        run(name, kind, data[kind], function(s) return charigo.convert(s, from, to) end)
    end
end

for _, kind in ipairs(order) do
    local s = inputs[kind]
    report("valid utf-8", kind, #s, best(function() assert(charigo.valid(s, "utf-8")) end))
end

for _, kind in ipairs(order) do
    local s = inputs[kind]
    local conv = charigo.converter("utf-8", "utf-16le")
    local small = s:sub(1, 64)
    while #small > 0 and not charigo.valid(small, "utf-8") do small = small:sub(1, -2) end
    local loops = smoke and 10 or 20000
    local tConvert = best(function()
        for _ = 1, loops do charigo.convert(small, "utf-8", "utf-16le") end
    end)
    local tConverter = best(function()
        for _ = 1, loops do conv(small) end
    end)
    local bytes = #small * loops
    report("small convert utf-8 -> utf-16le", kind, bytes, tConvert)
    report("small converter utf-8 -> utf-16le", kind, bytes, tConverter)
end

os.exit(0)
