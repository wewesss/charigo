local M = {}

local CODEPAGES = {
    [65001] = "utf-8",
    [1252] = "cp1252",
    [28591] = "latin1",
    [1200] = "utf-16le",
    [1201] = "utf-16be",
}

local CODESETS = {
    utf8 = "utf-8",
    iso88591 = "latin1",
    latin1 = "latin1",
    cp1252 = "cp1252",
    windows1252 = "cp1252",
}

local CDEF = "unsigned int GetACP(void); unsigned int GetConsoleOutputCP(void);"

local function pick(deps, key, default)
    local v = deps[key]
    if v == nil then return default() end
    return v
end

local function defaultIsWindows()
    if type(jit) == "table" and jit.os then return jit.os == "Windows" end
    return package.config:sub(1, 1) == "\\"
end

local function defaultFfi()
    local ok, ffi = pcall(require, "ffi")
    if ok then return ffi end
    return false
end

local function defaultGetenv() return os.getenv end
local function defaultPopen() return io.popen or false end

local function fromFfi(ffi)
    local ok, acp, console = pcall(function()
        pcall(ffi.cdef, CDEF)
        return tonumber(ffi.C.GetACP()), tonumber(ffi.C.GetConsoleOutputCP())
    end)
    if ok and acp then return acp, console end
end

local function fromChcp(popen)
    local ok, out = pcall(function()
        local f = popen("chcp")
        if not f then return nil end
        local text = f:read("*a")
        f:close()
        return text
    end)
    if not ok or type(out) ~= "string" then return nil end
    local last
    for token in out:gmatch("%d+") do last = token end
    if last then return tonumber(last), last end
end

local function windows(deps, info)
    info.os = "windows"
    local ffi = pick(deps, "ffi", defaultFfi)
    if ffi then
        local acp, console = fromFfi(ffi)
        if acp then
            info.source = "ffi"
            info.codepage = acp
            info.console_codepage = console
            info.raw = tostring(acp)
            info.console = console and CODEPAGES[console] or nil
            return CODEPAGES[acp]
        end
    end
    local popen = pick(deps, "popen", defaultPopen)
    if popen then
        local cp, token = fromChcp(popen)
        if cp then
            info.source = "chcp"
            info.codepage = cp
            info.console_codepage = cp
            info.raw = token
            info.console = CODEPAGES[cp]
            return CODEPAGES[cp]
        end
    end
end

local function posix(deps, info)
    info.os = "posix"
    local getenv = pick(deps, "getenv", defaultGetenv)
    local locale
    for _, name in ipairs({ "LC_ALL", "LC_CTYPE", "LANG" }) do
        local v = getenv(name)
        if v and v ~= "" then
            locale = v
            break
        end
    end
    if not locale then return nil end
    info.source = "env"
    info.raw = locale
    local codeset = locale:match("%.([^@]*)")
    if not codeset then return nil end
    local enc = CODESETS[codeset:lower():gsub("[-_]", "")]
    info.console = enc
    return enc
end

function M.detect(deps)
    deps = deps or {}
    local info = { source = "none" }
    local enc
    if pick(deps, "is_windows", defaultIsWindows) then
        enc = windows(deps, info)
    else
        enc = posix(deps, info)
    end
    return enc, info
end

return M
