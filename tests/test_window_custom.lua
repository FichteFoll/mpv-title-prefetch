package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local entries = {}
for n = 1, 13 do
    entries[#entries + 1] = h.fixture("titled-" .. n .. ".mkv")
end
h.setup{opts = {range = 2}, entries = entries, pos = 6}

local expected = {[4] = true, [5] = true, [6] = true, [7] = true, [8] = true}

h.wait_until("indices 4-8 are titled", function()
    for i in pairs(expected) do
        if h.title(i) ~= "Title " .. (i + 1) then
            return false
        end
    end
    return true
end, 20, function()
    h.wait_idle(function()
        for i = 0, 12 do
            if not expected[i] then
                h.expect_eq(h.title(i), nil, "title of index " .. i)
            end
        end
        h.pass()
    end)
end)
