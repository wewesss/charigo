local byte, char, find = string.byte, string.char, string.find
local concat, unpack = table.concat, unpack or table.unpack
local floor = math.floor

local HIGH = "[\128-\255]"
local CHUNK = 4096
local REPLACEMENT = 0xFFFD

local LEN, LO, HI = {}, {}, {}
for c = 0xC2, 0xDF do LEN[c] = 2; LO[c] = 0x80; HI[c] = 0xBF end
for c = 0xE0, 0xEF do LEN[c] = 3; LO[c] = 0x80; HI[c] = 0xBF end
for c = 0xF0, 0xF4 do LEN[c] = 4; LO[c] = 0x80; HI[c] = 0xBF end
LO[0xE0] = 0xA0
HI[0xED] = 0x9F
LO[0xF0] = 0x90
HI[0xF4] = 0x8F

local function scan(s, i)
    local c = byte(s, i)
    local n = LEN[c]
    if not n then return nil, 1 end
    local c2 = byte(s, i + 1)
    if not c2 or c2 < LO[c] or c2 > HI[c] then return nil, 1 end
    if n == 2 then
        return (c - 0xC0) * 64 + (c2 - 0x80), 2
    end
    local c3 = byte(s, i + 2)
    if not c3 or c3 < 0x80 or c3 > 0xBF then return nil, 2 end
    if n == 3 then
        return (c - 0xE0) * 4096 + (c2 - 0x80) * 64 + (c3 - 0x80), 3
    end
    local c4 = byte(s, i + 3)
    if not c4 or c4 < 0x80 or c4 > 0xBF then return nil, 3 end
    return (c - 0xF0) * 262144 + (c2 - 0x80) * 4096 + (c3 - 0x80) * 64 + (c4 - 0x80), 4
end

local function pushBytes(out, n, s, a, b)
    for k = a, b, CHUNK do
        local e = k + CHUNK - 1
        if e > b then e = b end
        local t = { byte(s, k, e) }
        for q = 1, #t do out[n + q] = t[q] end
        n = n + (e - k + 1)
    end
    return n
end

local POLICIES = { strict = true, replace = true, skip = true }

local M = {}

function M.policy(opts)
    local e = opts and opts.errors
    if e == nil then return "strict" end
    if not POLICIES[e] then
        error("charigo: unknown errors policy '" .. tostring(e) .. "'", 0)
    end
    return e
end

function M.decode(s, mode)
    local out, n = {}, 0
    local len = #s
    local i = 1
    while i <= len do
        local j = find(s, HIGH, i)
        if not j then
            n = pushBytes(out, n, s, i, len)
            break
        end
        if j > i then n = pushBytes(out, n, s, i, j - 1) end
        local cp, used = scan(s, j)
        if cp then
            n = n + 1
            out[n] = cp
        elseif mode == "strict" then
            error(("charigo: invalid utf-8 at byte %d"):format(j), 0)
        elseif mode == "replace" then
            n = n + 1
            out[n] = REPLACEMENT
        end
        i = j + used
    end
    return out
end

function M.valid(s)
    local len = #s
    local i = 1
    while i <= len do
        local j = find(s, HIGH, i)
        if not j then return true end
        local cp, used = scan(s, j)
        if not cp then return false, j end
        i = j + used
    end
    return true
end

function M.encode(cps, mode)
    local b, m = {}, 0
    for i = 1, #cps do
        local cp = cps[i]
        if type(cp) ~= "number" or cp % 1 ~= 0 or cp < 0 or cp > 0x10FFFF
            or (cp >= 0xD800 and cp <= 0xDFFF) then
            if mode == "strict" then
                error(("charigo: invalid code point at index %d"):format(i), 0)
            elseif mode == "replace" then
                b[m + 1], b[m + 2], b[m + 3] = 0xEF, 0xBF, 0xBD
                m = m + 3
            end
        elseif cp < 0x80 then
            m = m + 1
            b[m] = cp
        elseif cp < 0x800 then
            b[m + 1] = 0xC0 + floor(cp / 64)
            b[m + 2] = 0x80 + cp % 64
            m = m + 2
        elseif cp < 0x10000 then
            b[m + 1] = 0xE0 + floor(cp / 4096)
            b[m + 2] = 0x80 + floor(cp / 64) % 64
            b[m + 3] = 0x80 + cp % 64
            m = m + 3
        else
            b[m + 1] = 0xF0 + floor(cp / 262144)
            b[m + 2] = 0x80 + floor(cp / 4096) % 64
            b[m + 3] = 0x80 + floor(cp / 64) % 64
            b[m + 4] = 0x80 + cp % 64
            m = m + 4
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

return M
