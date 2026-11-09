local u8 = require("charigo.utf8")

local byte, char, find, gsub = string.byte, string.char, string.find, string.gsub
local concat, unpack = table.concat, unpack or table.unpack

local HIGH = "[\128-\255]"
local CHUNK = 4096

local function identityRange(t, from, to)
    for b = from, to do t[b - 0x7F] = b end
end

local latin1 = {}
identityRange(latin1, 0x80, 0xFF)

local cp1252 = {
    0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
    0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F,
    0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
    0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178,
}
identityRange(cp1252, 0xA0, 0xFF)

local function encodeCp(cp)
    if cp < 0x80 then return char(cp) end
    if cp < 0x800 then
        return char(0xC0 + (cp - cp % 64) / 64, 0x80 + cp % 64)
    end
    return char(
        0xE0 + (cp - cp % 4096) / 4096,
        0x80 + ((cp - cp % 64) / 64) % 64,
        0x80 + cp % 64
    )
end

local function build(name, high)
    local cs = { name = name, toCp = {}, fromCp = {}, utf8 = {} }
    for b = 0, 0x7F do
        cs.toCp[b] = b
        cs.fromCp[b] = b
    end
    for b = 0x80, 0xFF do
        local cp = high[b - 0x7F]
        cs.toCp[b] = cp
        cs.fromCp[cp] = b
        cs.utf8[char(b)] = encodeCp(cp)
    end
    return cs
end

local CHARSETS = {}
local ALIASES = {
    latin1 = { "latin1", "latin-1", "iso-8859-1" },
    cp1252 = { "cp1252", "windows-1252" },
}
local built = { latin1 = build("latin1", latin1), cp1252 = build("cp1252", cp1252) }
for canonical, names in pairs(ALIASES) do
    for i = 1, #names do CHARSETS[names[i]] = built[canonical] end
end

local M = {}

function M.get(name)
    if type(name) ~= "string" then return nil end
    return CHARSETS[name:lower()]
end

function M.toUtf8(cs, s)
    if not find(s, HIGH) then return s end
    return (gsub(s, HIGH, cs.utf8))
end

local function decode(cs, s)
    local out, n = {}, 0
    local toCp = cs.toCp
    for k = 1, #s, CHUNK do
        local e = k + CHUNK - 1
        if e > #s then e = #s end
        local t = { byte(s, k, e) }
        for q = 1, #t do out[n + q] = toCp[t[q]] end
        n = n + #t
    end
    return out
end

local function encode(cs, cps, mode)
    local fromCp = cs.fromCp
    local b, m = {}, 0
    for i = 1, #cps do
        local cp = cps[i]
        local v = fromCp[cp]
        if v then
            m = m + 1
            b[m] = v
        elseif mode == "strict" then
            if type(cp) ~= "number" or cp % 1 ~= 0 or cp < 0 or cp > 0x10FFFF
                or (cp >= 0xD800 and cp <= 0xDFFF) then
                error(("charigo: invalid code point at index %d"):format(i), 0)
            end
            error(("charigo: cannot encode U+%04X in %s at index %d"):format(cp, cs.name, i), 0)
        elseif mode == "replace" then
            m = m + 1
            b[m] = 0x3F
        end
    end
    local parts, pn = {}, 0
    for k = 1, m, CHUNK do
        local e = k + CHUNK - 1
        if e > m then e = m end
        pn = pn + 1
        parts[pn] = char(unpack(b, k, e))
    end
    return concat(parts)
end

function M.fromUtf8(cs, s, mode)
    return encode(cs, u8.decode(s, mode), mode)
end

function M.codec(cs)
    return {
        policy = u8.policy,
        decode = function(s) return decode(cs, s) end,
        encode = function(cps, mode) return encode(cs, cps, mode) end,
        valid = function() return true end,
    }
end

for _, cs in pairs(built) do cs.codec = M.codec(cs) end

return M
