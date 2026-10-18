package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local entries = {}
for n = 1, 10 do
    entries[#entries + 1] = h.fixture("titled-" .. n .. ".mkv")
end
h.setup{opts = {range = 1}, entries = entries, pos = 0}

-- An extension by resolve-more lasts until `range` changes,
-- which resets the effective range to the new value.
h.wait_until("index 1 is titled", function()
    return h.title(1) == "Title 2"
end, 20, function()
    h.wait_idle(function()
        mp.commandv("script-message-to", "title_prefetch", "resolve-more", "3")
        h.wait_until("indices 2-4 are titled", function()
            return h.title(2) == "Title 3" and h.title(3) == "Title 4" and h.title(4) == "Title 5"
        end, 20, function()
            h.wait_idle(function()
                h.expect_eq(h.title(5), nil, "title of index 5 at effective range 4")
                h.set_opts({range = 5})
                h.wait_until("index 5 is titled", function()
                    return h.title(5) == "Title 6"
                end, 20, function()
                    h.wait_idle(function()
                        h.expect_eq(h.title(6), nil, "title of index 6 after the reset to range 5")
                        h.pass()
                    end)
                end)
            end)
        end)
    end)
end)
