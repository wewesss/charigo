local u8 = require("charigo.utf8")

local charigo = { _VERSION = "0.0.0" }

local function notImplemented()
    error("not implemented", 2)
end

local function resolve(enc)
    local name = type(enc) == "string" and enc:lower() or nil
    if name == "utf-8" or name == "utf8" then return u8 end
    error("charigo: unknown encoding '" .. tostring(enc) .. "'", 3)
end

function charigo.decode(s, enc, opts)
    local codec = resolve(enc)
    return codec.decode(s, codec.policy(opts))
end

function charigo.encode(cps, enc, opts)
    local codec = resolve(enc)
    return codec.encode(cps, codec.policy(opts))
end

function charigo.valid(s, enc)
    return resolve(enc).valid(s)
end

charigo.convert = notImplemented
charigo.converter = notImplemented
charigo.detect = notImplemented

return charigo
