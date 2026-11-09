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
    local jit = rawget(_G, "jit")
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

local function run(popen, command)
    local ok, out = pcall(function()
        local f = popen(command)
        if not f then return nil end
        local text = f:read("*a")
        f:close()
        return text
    end)
    if ok and type(out) == "string" then return out end
end

local function fromChcp(popen)
    local out = run(popen, "chcp")
    if not out then return nil end
    local last
    for token in out:gmatch("%d+") do last = token end
    if last then return tonumber(last), last end
end

local function fromRegistry(popen)
    local out = run(popen, [[reg query "HKLM\SYSTEM\CurrentControlSet\Control\Nls\CodePage" /v ACP]])
    if not out then return nil end
    local token = out:match("REG_SZ%s+(%d+)")
    if token then return tonumber(token), token end
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
        local acp, acpToken = fromRegistry(popen)
        local console, consoleToken = fromChcp(popen)
        if acp or console then
            info.source = acp and "reg" or "chcp"
            info.codepage = acp
            info.console_codepage = console
            info.console = console and CODEPAGES[console] or nil
            info.raw = acpToken or consoleToken
            return acp and CODEPAGES[acp] or nil
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
