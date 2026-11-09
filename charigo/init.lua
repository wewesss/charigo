local charigo = { _VERSION = "0.0.0" }

local function notImplemented()
    error("not implemented", 2)
end

charigo.convert = notImplemented
charigo.converter = notImplemented
charigo.decode = notImplemented
charigo.encode = notImplemented
charigo.valid = notImplemented
charigo.detect = notImplemented

return charigo
