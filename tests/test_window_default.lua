package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local entries = {}
for n = 1, 13 do
    entries[#entries + 1] = h.fixture("titled-" .. n .. ".mkv")
end
h.setup{entries = entries, pos = 6}

local function window_titled()
    for i = 1, 11 do
        if i ~= 6 and h.title(i) ~= "Title " .. (i + 1) then
            return false
        end
    end
    return true
end

h.wait_until("indices 1-5 and 7-11 are titled", window_titled, 20, function()
    h.wait_idle(function()
        h.expect_eq(h.title(0), nil, "title of index 0")
        h.expect_eq(h.title(12), nil, "title of index 12")

        mp.commandv("loadlist", h.fixture("kept.m3u"), "append")
        h.set_opts({range = -1})
        h.wait_until("indices 0 and 12 are titled", function()
            return h.title(0) ~= nil and h.title(12) ~= nil
        end, 20, function()
            h.wait_idle(function()
                h.expect_eq(h.title(13), "Kept", "title of index 13")
                h.pass()
            end)
        end)
    end)
end)
