package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local entries = {}
for n = 1, 10 do
    entries[#entries + 1] = h.fixture("titled-" .. n .. ".mkv")
end
h.setup{opts = {range = 0}, entries = entries, pos = 0}

-- With `range=0`, resolve-more without an argument enables a range of 5.
h.wait_idle(function()
    h.expect_eq(h.title(1), nil, "title of index 1 before resolve-more")
    mp.commandv("script-message-to", "title_prefetch", "resolve-more")
    h.wait_until("indices 1-5 are titled", function()
        for i = 1, 5 do
            if h.title(i) ~= "Title " .. (i + 1) then
                return false
            end
        end
        return true
    end, 20, function()
        h.wait_idle(function()
            h.expect_eq(h.title(6), nil, "title of index 6 after resolve-more")
            h.pass()
        end)
    end)
end)
