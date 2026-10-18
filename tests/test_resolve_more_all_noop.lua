package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local entries = {}
for n = 1, 10 do
    entries[#entries + 1] = h.fixture("titled-" .. n .. ".mkv")
end
h.setup{opts = {range = -1}, entries = entries, pos = 0}

-- While the effective range is -1, a valid resolve-more does nothing:
-- it requests no pass, and it does not turn "all" into a finite range.
h.wait_until("index 9 is titled", function()
    return h.title(9) == "Title 10"
end, 20, function()
    h.wait_idle(function()
        local became_busy = false
        local function on_idle(_, idle)
            if idle == false then
                became_busy = true
            end
        end
        mp.observe_property("user-data/title-prefetch/idle", "native", on_idle)
        mp.commandv("script-message-to", "title_prefetch", "resolve-more", "1")
        h.wait_idle(function()
            mp.unobserve_property(on_idle)
            h.expect_eq(became_busy, false, "idle turned false after resolve-more")
            -- Distance 10 from the current entry: only resolved while the range is still "all".
            mp.commandv("loadfile", h.fixture("titled-11.mkv"), "append")
            h.wait_until("appended index 10 is titled", function()
                return h.title(10) == "Title 11"
            end, 20, function()
                h.wait_idle(h.pass)
            end)
        end)
    end)
end)
