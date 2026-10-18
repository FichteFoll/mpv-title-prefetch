package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local entries = {}
for n = 1, 10 do
    entries[#entries + 1] = h.fixture("titled-" .. n .. ".mkv")
end
h.setup{opts = {range = 1}, entries = entries, pos = 0}

h.wait_until("index 1 is titled", function()
    return h.title(1) == "Title 2"
end, 20, function()
    mp.set_property_number("playlist-pos", 7)
    h.wait_until("indices 6 and 8 are titled", function()
        return h.title(6) == "Title 7" and h.title(8) == "Title 9"
    end, 20, function()
        h.wait_idle(function()
            h.expect_eq(h.title(3), nil, "title of index 3")
            h.pass()
        end)
    end)
end)
