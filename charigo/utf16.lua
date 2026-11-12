local u8 = require("charigo.utf8")

local byte, char, find, gsub = string.byte, string.char, string.find, string.gsub
local concat, unpack = table.concat, unpack or table.unpack
local floor = math.floor

local CHUNK = 4096
local REPLACEMENT = 0xFFFD
local HIGH = "[\128-\255]"
local SEQUENCE = "[%z\1-\127\192-\255][\128-\191]*"
local MEMO_LIMIT = 4096

local KINDS = {
    ["utf-16le"] = { name = "utf-16le", order = "le" },
    ["utf-16be"] = { name = "utf-16be", order = "be" },
    ["utf-16"] = { name = "utf-16", order = "auto" },
}
KINDS["utf16le"] = KINDS["utf-16le"]
KINDS["utf16be"] = KINDS["utf-16be"]
KINDS["utf16"] = KINDS["utf-16"]

local function unit(s, i, be)
    local a, b = byte(s, i, i + 1)
    if be then return a * 256 + b end
    return b * 256 + a
end

local function walk(s, kind, mode)
    local len = #s
    local i = 1
    local be = kind.order == "be"
    if len >= 2 then
        local a, b = byte(s, 1, 2)
        if a == 0xFF and b == 0xFE and kind.order ~= "be" then
            be = false
            i = 3
        elseif a == 0xFE and b == 0xFF and kind.order ~= "le" then
            be = true
            i = 3
        end
    end
    local out, n = {}, 0
    while i + 1 <= len do
        local u = unit(s, i, be)
        local cp, used
        if u >= 0xD800 and u <= 0xDBFF then
            if i + 3 <= len then
                local lo = unit(s, i + 2, be)
                if lo >= 0xDC00 and lo <= 0xDFFF then
                    cp = 0x10000 + (u - 0xD800) * 1024 + (lo - 0xDC00)
                    used = 4
                end
            end
        elseif u < 0xDC00 or u > 0xDFFF then
            cp, used = u, 2
        end
        if cp then
            n = n + 1
            out[n] = cp
            i = i + used
        else
            if mode == "check" then return false, i end
            if mode == "strict" then
                error(("charigo: invalid utf-16 at byte %d"):format(i), 0)
            elseif mode == "replace" then
                n = n + 1
                out[n] = REPLACEMENT
            end
            i = i + 2
        end
    end
    if i == len then
        if mode == "check" then return false, i end
        if mode == "strict" then
            error(("charigo: invalid utf-16 at byte %d"):format(i), 0)
        elseif mode == "replace" then
            n = n + 1
            out[n] = REPLACEMENT
        end
    end
    if mode == "check" then return true end
    return out
end

local function encode(kind, bom, cps, mode)
    local be = kind.order == "be"
    local b, m = {}, 0
    local function put(u)
        local hi, lo = floor(u / 256), u % 256
        if be then
            b[m + 1], b[m + 2] = hi, lo
        else
            b[m + 1], b[m + 2] = lo, hi
        end
        m = m + 2
    end
    if bom then put(0xFEFF) end
    for i = 1, #cps do
        local cp = cps[i]
        if type(cp) ~= "number" or cp % 1 ~= 0 or cp < 0 or cp > 0x10FFFF
            or (cp >= 0xD800 and cp <= 0xDFFF) then
            if mode == "strict" then
                error(("charigo: invalid code point at index %d"):format(i), 0)
            elseif mode == "replace" then
                put(REPLACEMENT)
            end
        elseif cp < 0x10000 then
            put(cp)
        else
            local v = cp - 0x10000
            put(0xD800 + floor(v / 1024))
            put(0xDC00 + v % 1024)
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

local M = {}

function M.get(name)
    if type(name) ~= "string" then return nil end
    return KINDS[name:lower()]
end

local function unitBytes(u, be)
    local hi, lo = floor(u / 256), u % 256
    if be then return char(hi, lo) end
    return char(lo, hi)
end

local function pairBytes(cp, be)
    if cp < 0x10000 then return unitBytes(cp, be) end
    local v = cp - 0x10000
    return unitBytes(0xD800 + floor(v / 1024), be) .. unitBytes(0xDC00 + v % 1024, be)
end

local function codePointOf(seq)
    local a, b, c, d = byte(seq, 1, 4)
    if not b then return a end
    if not c then return (a - 0xC0) * 64 + (b - 0x80) end
    if not d then return (a - 0xE0) * 4096 + (b - 0x80) * 64 + (c - 0x80) end
    return (a - 0xF0) * 262144 + (b - 0x80) * 4096 + (c - 0x80) * 64 + (d - 0x80)
end

local gsubTables = {}

local function tablesFor(be)
    local key = be and "be" or "le"
    local cached = gsubTables[key]
    if cached then return cached end
    local ascii, memo, size = {}, {}, 0
    for b = 0, 127 do
        local v = pairBytes(b, be)
        ascii[char(b)] = v
        memo[char(b)] = v
        size = size + 1
    end
    setmetatable(memo, {
        __index = function(t, seq)
            local v = pairBytes(codePointOf(seq), be)
            if size < MEMO_LIMIT then
                size = size + 1
                rawset(t, seq, v)
            end
            return v
        end,
    })
    cached = { ascii = ascii, memo = memo }
    gsubTables[key] = cached
    return cached
end

function M.fromUtf8(kind, bom)
    local be = kind.order == "be"
    local t = tablesFor(be)
    local ascii, memo = t.ascii, t.memo
    local prefix = (bom or kind.order == "auto") and pairBytes(0xFEFF, be) or ""
    return function(s)
        if not find(s, HIGH) then
            return prefix .. (gsub(s, ".", ascii))
        end
        if not u8.valid(s) then return nil end
        return prefix .. (gsub(s, SEQUENCE, memo))
    end
end

local codecs = {}

function M.codec(kind, bom)
    bom = (bom or kind.order == "auto") and true or false
    local key = kind.name .. (bom and "+bom" or "")
    local codec = codecs[key]
    if codec then return codec end
    codec = {
        policy = u8.policy,
        decode = function(s, mode) return walk(s, kind, mode) end,
        encode = function(cps, mode) return encode(kind, bom, cps, mode) end,
        valid = function(s) return walk(s, kind, "check") end,
    }
    codecs[key] = codec
    return codec
end

return M
