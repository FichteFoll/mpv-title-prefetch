package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local entries = {}
for n = 1, 10 do
    entries[#entries + 1] = h.fixture("titled-" .. n .. ".mkv")
end
h.setup{opts = {range = 2}, entries = entries, pos = 0}

-- Without an argument, resolve-more adds the positive `range` option, here 2.
h.wait_until("indices 1 and 2 are titled", function()
    return h.title(1) == "Title 2" and h.title(2) == "Title 3"
end, 20, function()
    h.wait_idle(function()
        h.expect_eq(h.title(3), nil, "title of index 3 before resolve-more")
        mp.commandv("script-message-to", "title_prefetch", "resolve-more")
        h.wait_until("indices 3 and 4 are titled", function()
            return h.title(3) == "Title 4" and h.title(4) == "Title 5"
        end, 20, function()
            h.wait_idle(function()
                h.expect_eq(h.title(5), nil, "title of index 5 after resolve-more")
                h.pass()
            end)
        end)
    end)
end)
