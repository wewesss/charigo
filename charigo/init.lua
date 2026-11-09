local u8 = require("charigo.utf8")
local sbcs = require("charigo.sbcs")
local utf16 = require("charigo.utf16")
local sysos = require("charigo.os")

local charigo = { _VERSION = "0.0.0" }

local function resolve(enc, bom)
    local name = type(enc) == "string" and enc:lower() or nil
    if name == "utf-8" or name == "utf8" then return u8, u8 end
    local kind = utf16.get(name)
    if kind then return utf16.codec(kind, bom), kind end
    local cs = sbcs.get(name)
    if cs then return cs.codec, cs end
    error("charigo: unknown encoding '" .. tostring(enc) .. "'", 0)
end

local function bomOf(opts)
    return opts ~= nil and opts.bom == true
end

function charigo.decode(s, enc, opts)
    local codec = resolve(enc)
    return codec.decode(s, codec.policy(opts))
end

function charigo.encode(cps, enc, opts)
    local codec = resolve(enc, bomOf(opts))
    return codec.encode(cps, codec.policy(opts))
end

function charigo.valid(s, enc)
    return resolve(enc).valid(s)
end

function charigo.converter(from, to, opts)
    local src, srcId = resolve(from)
    local dst, dstId = resolve(to, bomOf(opts))
    local mode = u8.policy(opts)
    local decode, encode = src.decode, dst.encode

    if srcId == dstId and srcId.order == nil then
        local valid = src.valid
        if mode == "strict" then
            return function(s)
                if valid(s) then return s end
                return decode(s, mode)
            end
        end
        return function(s)
            return encode(decode(s, mode), mode)
        end
    end
    if srcId.toCp and dstId == u8 then
        return function(s) return sbcs.toUtf8(srcId, s) end
    end
    if srcId == u8 and dstId.toCp then
        return function(s) return sbcs.fromUtf8(dstId, s, mode) end
    end
    return function(s)
        return encode(decode(s, mode), mode)
    end
end

local cache = {}

function charigo.convert(s, from, to, opts)
    local key
    if type(from) == "string" and type(to) == "string" then
        local mode = opts and opts.errors
        key = from:lower() .. "\0" .. to:lower() .. "\0" .. tostring(mode)
            .. "\0" .. tostring(bomOf(opts))
        local fn = cache[key]
        if fn then return fn(s) end
    end
    local fn = charigo.converter(from, to, opts)
    if key then cache[key] = fn end
    return fn(s)
end

charigo._sbcs = sbcs

charigo._os = sysos

function charigo.detect()
    return sysos.detect()
end

return charigo
