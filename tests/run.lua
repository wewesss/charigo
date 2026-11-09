local mode
for _, a in ipairs(arg or {}) do
    if a == "dist" then mode = "dist" end
end
local charigo
if mode == "dist" then
    charigo = dofile("dist/charigo.lua")
else
    package.path = "./?.lua;./?/init.lua;" .. package.path
    charigo = require("charigo")
end

local passed, failed = 0, 0
local failures = {}

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        failures[#failures + 1] = name .. " :: " .. tostring(err)
    end
end

local function eq(actual, expected)
    if actual ~= expected and not (actual ~= actual and expected ~= expected) then
        error(("expected %s, got %s"):format(tostring(expected), tostring(actual)), 2)
    end
end

local function truthy(v) if not v then error("expected truthy", 2) end end
local function falsy(v) if v then error("expected falsy", 2) end end

local function raises(fn, pattern)
    local ok, err = pcall(fn)
    if ok then error("expected error", 2) end
    if pattern and not tostring(err):find(pattern, 1, true) then
        error(("expected error containing %q, got %s"):format(pattern, tostring(err)), 2)
    end
end

local env = {
    charigo = charigo, test = test, eq = eq,
    truthy = truthy, falsy = falsy, raises = raises,
}

local files = {
    "tests/api_test.lua",
}

for i = 1, #files do
    dofile(files[i])(env)
end

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
    print("Failures:")
    for i = 1, #failures do
        print("  - " .. failures[i])
    end
    os.exit(1)
end
