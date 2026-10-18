package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local entries = {}
for n = 1, 5 do
    entries[#entries + 1] = h.fixture("titled-" .. n .. ".mkv")
end
h.setup{opts = {range = 0}, entries = entries, pos = 2}

h.wait_idle(function()
    for i = 0, 4 do
        if i ~= 2 then
            h.expect_eq(h.title(i), nil, "title of index " .. i)
        end
    end
    -- Positive control: the same setup resolves titles once enabled.
    h.set_opts({range = 1})
    h.wait_until("index 3 is titled", function()
        return h.title(3) == "Title 4"
    end, 20, h.pass)
end)
