local OUT_DIR = "dist"
local OUT_FILE = OUT_DIR .. "/charigo.lua"
local ENTRY = "charigo/init.lua"

local MODULES = {
}

local reqToVar = {}
for i = 1, #MODULES do reqToVar[MODULES[i].req] = MODULES[i].var end

local function readFile(path)
    local f = assert(io.open(path, "rb"), "Cannot open " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

local function writeFile(path, content)
    local f = assert(io.open(path, "wb"), "Cannot write " .. path)
    f:write(content)
    f:close()
end

local function ensureDir(path)
    if package.config:sub(1, 1) == "\\" then
        local winPath = path:gsub("/", "\\")
        os.execute(string.format([[if not exist "%s" mkdir "%s"]], winPath, winPath))
    else
        os.execute(string.format([[mkdir -p "%s"]], path))
    end
end

local function rewriteRequires(body)
    local function sub(req)
        local var = reqToVar[req]
        if not var then error("Unknown require in source: " .. req) end
        return var
    end
    body = body:gsub('require%s*%(%s*"([^"]+)"%s*%)', sub)
    body = body:gsub("require%s*%(%s*'([^']+)'%s*%)", sub)
    return body
end

local function splitTrailingReturn(body)
    local trimmed = body:gsub("%s+$", "")
    local before, name = trimmed:match("^(.-)\n?return%s+([%w_]+)$")
    if not before then
        error("Could not find trailing `return <ident>` in module body")
    end
    before = before:gsub("\n+$", "")
    return before, name
end

local function indentBlock(s, prefix)
    local out, n = {}, 0
    for line in (s .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        out[n] = line == "" and "" or (prefix .. line)
    end
    if out[n] == "" then out[n] = nil end
    return table.concat(out, "\n")
end

local parts, pn = {}, 0
local function emit(line) pn = pn + 1; parts[pn] = line end

if #MODULES > 0 then
    local names = {}
    for i = 1, #MODULES do names[i] = MODULES[i].var end
    emit("local " .. table.concat(names, ", "))
    emit("")
end

for i = 1, #MODULES do
    local mod = MODULES[i]
    local body = rewriteRequires(readFile(mod.file))
    local before, retName = splitTrailingReturn(body)
    emit("do")
    emit(indentBlock(before, "    "))
    emit("    " .. mod.var .. " = " .. retName)
    emit("end")
    emit("")
end

emit((rewriteRequires(readFile(ENTRY)):gsub("%s+$", "")))

ensureDir(OUT_DIR)

local out = table.concat(parts, "\n") .. "\n"
writeFile(OUT_FILE, out)
print(string.format("Wrote %s (%d bytes)", OUT_FILE, #out))
