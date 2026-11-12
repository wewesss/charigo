local smoke = false
for _, a in ipairs(arg or {}) do
    if a == "--smoke" then smoke = true end
end

package.path = "./?.lua;./?/init.lua;" .. package.path
local charigo = require("charigo")

local TARGET = smoke and 2048 or 1024 * 1024
local SAMPLES = smoke and 1 or 3
local MIN_TIME = smoke and 0.005 or 0.2
local CHUNK = 4096
local unpackFn = table.unpack or unpack

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
    latin1 = fill("L'\195\169t\195\169 dernier, \195\160 Gen\195\168ve, le ma\195\174tre a d\195\169pos\195\169 son \195\169cole. "),
}
local order = { "ascii", "french", "emoji" }

local function rate(fn, bytes)
    local top = 0
    for _ = 1, SAMPLES do
        local loops = 0
        local t0 = os.clock()
        local elapsed
        repeat
            fn()
            loops = loops + 1
            elapsed = os.clock() - t0
        until elapsed >= MIN_TIME
        local mbps = bytes * loops / 1048576 / elapsed
        if mbps > top then top = mbps end
    end
    return top
end

local function firstLine(msg)
    msg = tostring(msg)
    return (msg:match("^[^\r\n]*"):gsub("|", "/"))
end

local rows = {}

local function absent(competitor, reason)
    rows[#rows + 1] = ("| (all) | - | - | %s | absent (%s) | - |"):format(competitor, firstLine(reason))
end

local function compare(competitor, scenario, kind, bytes, mine, theirs)
    local ok, err = pcall(function()
        local a, b = mine(), theirs()
        if a ~= b then error("output differs from charigo", 0) end
    end)
    if not ok then
        rows[#rows + 1] = ("| %s | %s | - | %s | absent (%s) | - |"):format(scenario, kind, competitor, firstLine(err))
        return
    end
    local m = rate(mine, bytes)
    local t = rate(theirs, bytes)
    rows[#rows + 1] = ("| %s | %s | %.1f | %s | %.1f | %.2fx |"):format(scenario, kind, m, competitor, t, m / t)
end

local runtime = rawget(_G, "jit") and jit.version or _VERSION

local native = rawget(_G, "utf8")
if type(native) == "table" and native.len and native.codes and native.char then
    for _, kind in ipairs(order) do
        local s = inputs[kind]
        local cps = charigo.decode(s, "utf-8")
        compare("utf8 (native)", "validate utf-8", kind, #s,
            function() return tostring(charigo.valid(s, "utf-8")) end,
            function() return tostring(native.len(s) ~= nil) end)
        compare("utf8 (native)", "utf-8 -> code points", kind, #s,
            function() return #charigo.decode(s, "utf-8") end,
            function()
                local t, n = {}, 0
                for _, c in native.codes(s) do
                    n = n + 1
                    t[n] = c
                end
                return #t
            end)
        compare("utf8 (native)", "code points -> utf-8", kind, #s,
            function() return charigo.encode(cps, "utf-8") end,
            function()
                local parts, pn = {}, 0
                for k = 1, #cps, CHUNK do
                    local e = k + CHUNK - 1
                    if e > #cps then e = #cps end
                    pn = pn + 1
                    parts[pn] = native.char(unpackFn(cps, k, e))
                end
                return table.concat(parts)
            end)
    end
else
    absent("utf8 (native)", "needs Lua 5.3 or later")
end

local conversions = {
    { "utf-8 -> cp1252", "utf-8", "cp1252", "CP1252", "UTF-8", { "ascii", "french" } },
    { "cp1252 -> utf-8", "cp1252", "utf-8", "UTF-8", "CP1252", { "ascii", "french" } },
    { "utf-8 -> latin1", "utf-8", "latin1", "LATIN1", "UTF-8", { "ascii", "latin1" } },
    { "latin1 -> utf-8", "latin1", "utf-8", "UTF-8", "LATIN1", { "ascii", "latin1" } },
    { "utf-8 -> utf-16le", "utf-8", "utf-16le", "UTF-16LE", "UTF-8", order },
    { "utf-16le -> utf-8", "utf-16le", "utf-8", "UTF-8", "UTF-16LE", order },
}

local okIconv, iconv = pcall(require, "iconv")
if not okIconv then
    absent("lua-iconv", iconv)
else
    for _, sc in ipairs(conversions) do
        for _, kind in ipairs(sc[6]) do
            local data = charigo.convert(inputs[kind], "utf-8", sc[2])
            local okOpen, cd = pcall(iconv.open, sc[4], sc[5])
            if not okOpen or not cd then
                rows[#rows + 1] = ("| %s | %s | - | lua-iconv | absent (%s) | - |"):format(
                    sc[1], kind, firstLine(cd or "open failed"))
            else
                compare("lua-iconv", sc[1], kind, #data,
                    function() return charigo.convert(data, sc[2], sc[3]) end,
                    function() return (assert(cd:iconv(data))) end)
            end
        end
    end
end

local okFfi, ffi = pcall(require, "ffi")
if not (rawget(_G, "jit") and okFfi) then
    absent("Win32 API (ffi)", "needs LuaJIT with ffi")
elseif package.config:sub(1, 1) ~= "\\" then
    absent("Win32 API (ffi)", "needs Windows")
else
    local okDef, defErr = pcall(ffi.cdef, [[
        int MultiByteToWideChar(unsigned int cp, unsigned long flags, const char *src, int srclen, wchar_t *dst, int dstlen);
        int WideCharToMultiByte(unsigned int cp, unsigned long flags, const wchar_t *src, int srclen, char *dst, int dstlen, const char *def, int *used);
    ]])
    if not okDef then
        absent("Win32 API (ffi)", defErr)
    else
        local C = ffi.C
        local function toWide(cp, s)
            local n = C.MultiByteToWideChar(cp, 0, s, #s, nil, 0)
            local buf = ffi.new("wchar_t[?]", n)
            C.MultiByteToWideChar(cp, 0, s, #s, buf, n)
            return buf, n
        end
        local function fromWide(cp, buf, n)
            local m = C.WideCharToMultiByte(cp, 0, buf, n, nil, 0, nil, nil)
            local out = ffi.new("char[?]", m)
            C.WideCharToMultiByte(cp, 0, buf, n, out, m, nil, nil)
            return ffi.string(out, m)
        end
        local function utf8ToUtf16(s)
            local buf, n = toWide(65001, s)
            return ffi.string(buf, n * 2)
        end
        local function utf16ToUtf8(s)
            local n = #s / 2
            local buf = ffi.new("wchar_t[?]", n)
            ffi.copy(buf, s, #s)
            return fromWide(65001, buf, n)
        end
        local function cp1252ToUtf8(s)
            local buf, n = toWide(1252, s)
            return fromWide(65001, buf, n)
        end
        local win = {
            { "utf-8 -> utf-16le", "utf-8", "utf-16le", utf8ToUtf16, order },
            { "utf-16le -> utf-8", "utf-16le", "utf-8", utf16ToUtf8, order },
            { "cp1252 -> utf-8", "cp1252", "utf-8", cp1252ToUtf8, { "ascii", "french" } },
        }
        for _, sc in ipairs(win) do
            for _, kind in ipairs(sc[5]) do
                local data = charigo.convert(inputs[kind], "utf-8", sc[2])
                compare("Win32 API (ffi)", sc[1], kind, #data,
                    function() return charigo.convert(data, sc[2], sc[3]) end,
                    function() return sc[4](data) end)
            end
        end
    end
end

print(("# charigo %s vs competitors"):format(charigo._VERSION))
print()
print(("Runtime: %s. Date: %s. Input ~%d bytes%s. Ratio = charigo / competitor."):format(
    runtime, os.date("%Y-%m-%d"), TARGET, smoke and " (smoke)" or ""))
print()
print("| scenario | input | charigo MB/s | competitor | competitor MB/s | ratio |")
print("| --- | --- | ---: | --- | ---: | ---: |")
for i = 1, #rows do print(rows[i]) end

os.exit(0)
