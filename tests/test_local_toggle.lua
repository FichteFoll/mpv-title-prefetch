package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local entries = {}
for n = 1, 3 do
    entries[#entries + 1] = h.fixture("titled-" .. n .. ".mkv")
end
h.setup{opts = {resolve_local = false}, entries = entries, pos = 0}

h.wait_idle(function()
    h.expect_eq(h.title(1), nil, "title of index 1")
    h.expect_eq(h.title(2), nil, "title of index 2")
    -- Positive control: the same setup resolves titles once enabled.
    h.set_opts({resolve_local = true})
    h.wait_until("index 1 is titled", function()
        return h.title(1) == "Title 2"
    end, 20, h.pass)
end)
