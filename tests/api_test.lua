return function(env)
    local test, eq, raises, charigo = env.test, env.eq, env.raises, env.charigo

    test("module loads as a table", function()
        eq(type(charigo), "table")
    end)

    test("_VERSION is a string", function()
        eq(type(charigo._VERSION), "string")
    end)

    test("_VERSION matches the release rockspec", function()
        local f = io.open("charigo-" .. charigo._VERSION .. "-1.rockspec", "rb")
        if not f then error("no rockspec named for version " .. charigo._VERSION) end
        local text = f:read("*a")
        f:close()
        eq(text:match('\nversion%s*=%s*"([^"]+)"'), charigo._VERSION .. "-1")
    end)

    local names = { "convert", "converter", "decode", "encode", "valid", "detect" }
    for i = 1, #names do
        local name = names[i]
        test("api " .. name .. " is a function", function()
            eq(type(charigo[name]), "function")
        end)
    end

    test("decode, encode, valid, convert and converter are implemented", function()
        eq(#charigo.decode("a", "utf-8"), 1)
        eq(charigo.encode({ 97 }, "utf-8"), "a")
        eq(charigo.valid("a", "utf-8"), true)
        eq(charigo.convert("a", "utf-8", "latin1"), "a")
        eq(charigo.converter("utf-8", "latin1")("a"), "a")
        eq(type(charigo.detect), "function")
    end)
end
