return function(env)
    local test, eq, raises, charigo = env.test, env.eq, env.raises, env.charigo

    test("module loads as a table", function()
        eq(type(charigo), "table")
    end)

    test("_VERSION is a string", function()
        eq(type(charigo._VERSION), "string")
    end)

    local names = { "convert", "converter", "decode", "encode", "valid", "detect" }
    for i = 1, #names do
        local name = names[i]
        test("api " .. name .. " is a function", function()
            eq(type(charigo[name]), "function")
        end)
    end

    test("convert errors while unimplemented", function()
        raises(function() charigo.convert("a", "utf8", "latin1") end, "not implemented")
    end)
end
